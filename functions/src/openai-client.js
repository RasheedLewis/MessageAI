const {
    getRequiredConfig,
    getOptionalConfig,
    CONFIG_KEYS,
} = require("./config");

let cachedClient;

const createClient = () => {
    const { OpenAI } = require("openai");
    const options = {
        apiKey: getRequiredConfig(CONFIG_KEYS.OPENAI_API_KEY),
    };

    const baseURL = getOptionalConfig(
        CONFIG_KEYS.OPENAI_API_BASE_URL,
        undefined,
    );
    if (baseURL) {
        options.baseURL = baseURL;
    }

    return new OpenAI(options);
};

const getClient = () => {
    if (!cachedClient) {
        cachedClient = createClient();
    }
    return cachedClient;
};

module.exports = {
    getClient,
};

