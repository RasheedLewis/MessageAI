const functions = require("firebase-functions/v1");

const CONFIG_KEYS = {
    OPENAI_API_KEY: "openai.apikey",
    OPENAI_API_BASE_URL: "openai.api_base_url",
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

module.exports = {
    CONFIG_KEYS,
    getConfigValue,
    getRequiredConfig,
    getOptionalConfig,
};

