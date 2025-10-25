const admin = require("firebase-admin");
const functions = require("firebase-functions/v1");

let initialized = false;

const initializeApp = () => {
    if (!initialized) {
        admin.initializeApp();
        functions.logger.info("Firebase Admin initialized");
        initialized = true;
    }
};

initializeApp();

module.exports = {
    admin,
    functions,
};

