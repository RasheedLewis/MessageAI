const functions = require("firebase-functions/v1");

const CONFIG_KEYS = {
    OPENAI_API_KEY: "openai.apikey",
    OPENAI_API_BASE_URL: "openai.api_base_url",
    OPENAI_CHAT_MODEL: "openai.chat_model",
    OPENAI_TIMEOUT_MS: "openai.timeout_ms",
    OPENAI_MAX_RETRIES: "openai.max_retries",
    OPENAI_RETRY_BASE_DELAY_MS: "openai.retry_base_delay_ms",
    OPENAI_RATE_LIMIT_RPM: "openai.rate_limit_rpm",
    OPENAI_RATE_LIMIT_CONCURRENCY: "openai.rate_limit_concurrency",
};

const getConfigValue = (key, fallback = undefined) => {
    try {
        const parts = key.split(".");
        const config = functions.config();
        const result = parts.reduce((acc, part) => {
            if (!acc || !Object.prototype.hasOwnProperty.call(acc, part)) {
                return undefined;
            }
            return acc[part];
        }, config);

        if (result === undefined || result === null) {
            return fallback;
        }
        return result;
    } catch (error) {
        return fallback;
    }
};

const getRequiredConfig = (key, fallback = undefined) => {
    const value = getConfigValue(key, fallback);
    if (!value) {
        throw new Error(`Missing required config value for ${key}`);
    }
    return value;
};

const getOptionalConfig = (key, fallback = undefined) => {
    return getConfigValue(key, fallback);
};

const parseNumber = (value) => {
    if (value === undefined || value === null) {
        return undefined;
    }
    const number = Number(value);
    if (Number.isNaN(number)) {
        return undefined;
    }
    return number;
};

const getIntegerConfig = (key, fallback = undefined) => {
    const value = getOptionalConfig(key, undefined);
    const parsed = parseNumber(value);
    if (parsed === undefined) {
        return fallback;
    }
    return Math.trunc(parsed);
};

const getNumberConfig = (key, fallback = undefined) => {
    const parsed = parseNumber(getOptionalConfig(key, undefined));
    if (parsed === undefined) {
        return fallback;
    }
    return parsed;
};

module.exports = {
    CONFIG_KEYS,
    getConfigValue,
    getRequiredConfig,
    getOptionalConfig,
    getIntegerConfig,
    getNumberConfig,
};

