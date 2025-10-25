const {
    getOptionalConfig,
    getIntegerConfig,
    getNumberConfig,
    CONFIG_KEYS,
} = require("../config");
const { getClient } = require("../openai-client");
const { withRetry } = require("../utils/retry");
const { TokenBucket } = require("../utils/token-bucket");
const { logInfo, logWarn } = require("../logger");

const DEFAULT_MODEL = "gpt-4o-mini";
const DEFAULT_TIMEOUT_MS = 15000;
const DEFAULT_MAX_RETRIES = 3;
const DEFAULT_RETRY_BASE_DELAY_MS = 250;
const DEFAULT_RATE_LIMIT_RPM = 60;
const DEFAULT_RATE_LIMIT_CONCURRENCY = 5;

let rateLimiter;

const ensureRateLimiter = () => {
    if (rateLimiter) {
        return rateLimiter;
    }

    const rpm = getIntegerConfig(
        CONFIG_KEYS.OPENAI_RATE_LIMIT_RPM,
        DEFAULT_RATE_LIMIT_RPM,
    );
    const concurrency = getIntegerConfig(
        CONFIG_KEYS.OPENAI_RATE_LIMIT_CONCURRENCY,
        DEFAULT_RATE_LIMIT_CONCURRENCY,
    );

    rateLimiter = {
        rpmBucket: new TokenBucket({
            tokensPerInterval: rpm,
            intervalMs: 60000,
            maxTokens: rpm,
        }),
        concurrencyBucket: new TokenBucket({
            tokensPerInterval: concurrency,
            intervalMs: 1000,
            maxTokens: concurrency,
        }),
    };

    return rateLimiter;
};

const runWithRateLimits = async (operation) => {
    const limiter = ensureRateLimiter();
    const rpmTimeoutMs = 2000;
    const concurrencyTimeoutMs = 2000;

    const rpmAcquired = await limiter.rpmBucket.removeToken(rpmTimeoutMs);
    if (!rpmAcquired) {
        throw new Error("Rate limit (RPM) exceeded for OpenAI requests");
    }

    const concurrencyBucket = limiter.concurrencyBucket;
    const concurrencyAcquired = await concurrencyBucket
        .removeToken(concurrencyTimeoutMs);
    if (!concurrencyAcquired) {
        const concurrencyMessage =
            "Rate limit (concurrency) exceeded for OpenAI requests";
        throw new Error(concurrencyMessage);
    }

    try {
        return await operation();
    } finally {
        limiter.concurrencyBucket.releaseToken();
    }
};

const shouldRetry = (error) => {
    if (!error || !error.status) {
        return false;
    }
    const retryStatusCodes = [408, 429, 500, 502, 503, 504];
    return retryStatusCodes.includes(error.status);
};

const buildChatPayload = ({
    messages,
    model,
    temperature,
    maxTokens,
    responseFormat,
    metadata,
}) => {
    const payload = {
        model: model || getOptionalConfig(
            CONFIG_KEYS.OPENAI_CHAT_MODEL,
            DEFAULT_MODEL,
        ),
        messages,
    };

    if (temperature !== undefined) {
        payload.temperature = temperature;
    }
    if (maxTokens !== undefined) {
        payload.max_tokens = maxTokens;
    }
    if (responseFormat) {
        payload.response_format = responseFormat;
    }
    if (metadata) {
        payload.metadata = metadata;
    }

    return payload;
};

const chatCompletion = async (options) => {
    const client = getClient();
    const timeoutMs = getIntegerConfig(
        CONFIG_KEYS.OPENAI_TIMEOUT_MS,
        DEFAULT_TIMEOUT_MS,
    );
    const maxRetries = getIntegerConfig(
        CONFIG_KEYS.OPENAI_MAX_RETRIES,
        DEFAULT_MAX_RETRIES,
    );
    const baseDelayMs = getNumberConfig(
        CONFIG_KEYS.OPENAI_RETRY_BASE_DELAY_MS,
        DEFAULT_RETRY_BASE_DELAY_MS,
    );

    return runWithRateLimits(() => withRetry(
        async (attempt) => {
            if (attempt > 0) {
                logWarn("Retrying OpenAI chat completion", { attempt });
            }
            const payload = buildChatPayload(options);

            const controller = new AbortController();
            const timeoutId = setTimeout(() => controller.abort(), timeoutMs);

            try {
                const response = await client.chat.completions.create(
                    payload,
                    {
                        signal: controller.signal,
                    },
                );
                logInfo("OpenAI chat completion success", {
                    model: payload.model,
                });
                return response;
            } finally {
                clearTimeout(timeoutId);
            }
        },
        {
            retries: maxRetries,
            baseDelayMs,
            shouldRetry,
        },
    ));
};

module.exports = {
    chatCompletion,
    DEFAULT_MODEL,
};

