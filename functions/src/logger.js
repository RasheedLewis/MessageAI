const { functions } = require("./app");

const logInfo = (message, data = undefined) => {
    if (data !== undefined) {
        functions.logger.info(message, data);
        return;
    }
    functions.logger.info(message);
};

const logWarn = (message, data = undefined) => {
    if (data !== undefined) {
        functions.logger.warn(message, data);
        return;
    }
    functions.logger.warn(message);
};

const logError = (message, error = undefined) => {
    if (error) {
        functions.logger.error(message, error);
        return;
    }
    functions.logger.error(message);
};

module.exports = {
    logInfo,
    logWarn,
    logError,
};

