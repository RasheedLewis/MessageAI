const chai = require("chai");
const sinon = require("sinon");
const chaiAsPromised = require("chai-as-promised");

const functionsTest = require("firebase-functions-test")();

chai.use(chaiAsPromised);
const { expect } = chai;

const sandbox = sinon.createSandbox();

describe("generateResponse", () => {
    let wrapped;
    let chatCompletionStub;

    beforeEach(() => {
        sandbox.restore();
        delete require.cache[require.resolve("../src/services/openai-service")];
        delete require.cache[require.resolve("../src/functions/generate-response")];

        chatCompletionStub = sandbox.stub().resolves({
            choices: [
                {
                    message: {
                        content: JSON.stringify({
                            reply: "Thanks for reaching out!",
                            tone: "friendly",
                            format: "paragraph",
                            reasoning: "Matches creator style.",
                            followUpQuestions: ["Do you have a deadline?"],
                            suggestedNextActions: ["Share rate card"],
                        }),
                    },
                },
            ],
        });

        sandbox.stub(
            require("../src/services/openai-service"),
            "chatCompletion",
        ).callsFake(chatCompletionStub);

        const generateResponse = require("../src/functions/generate-response");
        wrapped = functionsTest.wrap(generateResponse);
    });

    afterEach(() => {
        sandbox.restore();
    });

    it("returns generated reply with sanitized fields", async () => {
        const data = {
            message: "We'd love to collaborate",
            conversationHistory: [
                { speaker: "Fan", content: "Hey!" },
                { speaker: "Creator", content: "Hello!" },
            ],
            creatorProfile: {
                displayName: "Rae",
                persona: "Energetic fitness coach",
                defaultTone: "friendly",
                styleGuidelines: ["Encourage healthy habits"],
                voiceSamples: ["Let's crush it today!"],
                signature: "- Rae",
            },
            responsePreferences: {
                tone: "professional",
                includeSignature: true,
            },
        };

        const context = {
            auth: {
                uid: "creator123",
            },
        };

        const result = await wrapped(data, context);

        expect(result.reply).to.equal("Thanks for reaching out!");
        expect(result.tone).to.equal("friendly");
        expect(result.format).to.equal("paragraph");
        expect(result.reasoning).to.equal("Matches creator style.");
        expect(result.followUpQuestions).to.deep.equal(["Do you have a deadline?"]);
        expect(result.suggestedNextActions).to.deep.equal(["Share rate card"]);
    });

    it("rejects unauthenticated requests", async () => {
        const data = { message: "hi" };
        await expect(wrapped(data, {}))
            .to.be.rejectedWith("Authentication required to generate response");
    });

    it("rejects when message missing", async () => {
        const context = { auth: { uid: "123" } };
        await expect(wrapped({}, context))
            .to.be.rejectedWith("Message text is required for response generation");
    });

    it("throws internal error when OpenAI fails", async () => {
        sandbox.restore();
        sandbox.stub(
            require("../src/services/openai-service"),
            "chatCompletion",
        ).rejects(new Error("OpenAI failure"));

        delete require.cache[require.resolve("../src/functions/generate-response")];
        const generateResponse = require("../src/functions/generate-response");
        wrapped = functionsTest.wrap(generateResponse);

        const data = { message: "hello" };
        const context = { auth: { uid: "123" } };

        await expect(wrapped(data, context))
            .to.be.rejectedWith("Failed to generate response");
    });
});

