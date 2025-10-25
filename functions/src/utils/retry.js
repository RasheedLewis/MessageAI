const wait = (ms) => {
    return new Promise((resolve) => {
        setTimeout(resolve, ms);
    });
};

const withRetry = async (
    operation,
    {
        retries = 3,
        baseDelayMs = 200,
        multiplier = 2,
        shouldRetry = () => true,
    } = {},
) => {
    let attempt = 0;
    let lastError;

    while (attempt <= retries) {
        try {
            return await operation(attempt);
        } catch (error) {
            lastError = error;
            if (!shouldRetry(error, attempt) || attempt === retries) {
                throw error;
            }

            const delay = baseDelayMs * Math.pow(multiplier, attempt);
            await wait(delay);
            attempt += 1;
        }
    }

    throw lastError;
};

module.exports = {
    withRetry,
};

