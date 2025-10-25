const chai = require("chai");
const sinon = require("sinon");
const chaiAsPromised = require("chai-as-promised");

const functionsTest = require("firebase-functions-test")();

chai.use(chaiAsPromised);
const { expect } = chai;

const sandbox = sinon.createSandbox();

describe("analyzeMessage", () => {
    let wrapped;
    let chatCompletionStub;

    beforeEach(() => {
        sandbox.restore();
        delete require.cache[require.resolve("../src/services/openai-service")];
        delete require.cache[require.resolve("../src/functions/analyze-message")];

        chatCompletionStub = sandbox.stub().resolves({
            choices: [
                {
                    message: {
                        content: JSON.stringify({
                            category: "business",
                            sentiment: "positive",
                            priority: 4,
                            collaborationScore: 0.7,
                            summary: "Business inquiry",
                            extractedInfo: {
                                keyFacts: ["Fact"],
                                requestedActions: ["Call back"],
                                mentionedBrands: ["Brand"],
                            },
                        }),
                    },
                },
            ],
        });

        sandbox.stub(
            require("../src/services/openai-service"),
            "chatCompletion",
        ).callsFake(chatCompletionStub);

        const analyzeMessage = require("../src/functions/analyze-message");
        wrapped = functionsTest.wrap(analyzeMessage);
    });

    afterEach(() => {
        sandbox.restore();
    });

    it("should return structured analysis when OpenAI responds", async () => {
        const data = {
            message: "Hello, we want to sponsor you",
        };

        const context = {
            auth: {
                uid: "user123",
            },
        };

        const result = await wrapped(data, context);

        expect(result.category).to.equal("business");
        expect(result.sentiment).to.equal("positive");
        expect(result.priority).to.equal(4);
        expect(result.collaborationScore).to.equal(0.7);
        expect(result.summary).to.equal("Business inquiry");
        expect(result.extractedInfo.keyFacts).to.deep.equal(["Fact"]);
    });

    it("should throw unauthenticated when auth missing", async () => {
        const data = { message: "hi" };
        await expect(wrapped(data, {}))
            .to.be.rejectedWith("Authentication required to analyze message");
    });

    it("should throw invalid argument when message missing", async () => {
        const context = { auth: { uid: "abc" } };
        await expect(wrapped({}, context))
            .to.be.rejectedWith("Message text is required");
    });

    it("should propagate internal errors", async () => {
        sandbox.restore();
        sandbox.stub(
            require("../src/services/openai-service"),
            "chatCompletion",
        ).rejects(new Error("Timeout"));

        delete require.cache[require.resolve("../src/functions/analyze-message")];
        const analyzeMessage = require("../src/functions/analyze-message");
        wrapped = functionsTest.wrap(analyzeMessage);

        const data = { message: "error" };
        const context = { auth: { uid: "abc" } };

        await expect(wrapped(data, context))
            .to.be.rejectedWith("Failed to analyze message");
    });
});

