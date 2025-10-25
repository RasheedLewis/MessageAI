/**
 * Simple token bucket implementation for rate limiting.
 */
class TokenBucket {
    /**
     * @param {Object} params Bucket configuration.
     * @param {number} params.tokensPerInterval Tokens added per interval.
     * @param {number} params.intervalMs Interval duration in milliseconds.
 * @param {number=} params.maxTokens Bucket capacity override.
     */
    constructor({ tokensPerInterval, intervalMs, maxTokens }) {
        this.tokensPerInterval = tokensPerInterval;
        this.intervalMs = intervalMs;
        const hasProvidedMax = maxTokens !== undefined && maxTokens !== null;
        this.maxTokens = hasProvidedMax ? maxTokens : tokensPerInterval;
        this.availableTokens = this.maxTokens;
        this.lastRefill = Date.now();
    }

    /**
     * Refill tokens based on elapsed time.
     */
    refill() {
        const now = Date.now();
        const elapsed = now - this.lastRefill;
        if (elapsed <= 0) {
            return;
        }

        const elapsedRatio = elapsed / this.intervalMs;
        const tokensToAdd = elapsedRatio * this.tokensPerInterval;
        this.availableTokens = Math.min(
            this.maxTokens,
            this.availableTokens + tokensToAdd,
        );
        this.lastRefill = now;
    }

    /**
     * Attempt to remove a token. Waits until timeout if necessary.
     * @param {number} timeoutMs Timeout in milliseconds.
     * @return {Promise<boolean>} Whether a token was acquired.
     */
    async removeToken(timeoutMs = 1000) {
        const start = Date.now();
        while (Date.now() - start < timeoutMs) {
            this.refill();
            if (this.availableTokens >= 1) {
                this.availableTokens -= 1;
                return true;
            }

            await new Promise((resolve) => setTimeout(resolve, 50));
        }
        return false;
    }

    /**
     * Release a token back to the bucket.
     */
    releaseToken() {
        this.availableTokens = Math.min(
            this.availableTokens + 1,
            this.maxTokens,
        );
    }
}

module.exports = {
    TokenBucket,
};

