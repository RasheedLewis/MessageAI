const { functions } = require("../app");
const { chatCompletion, DEFAULT_MODEL } = require(
    "../services/openai-service",
);
const { MessageIntent, SentimentLabel } = require(
    "../types/analyze-message",
);
const { logError } = require("../logger");

const systemPrompt = [
    "You are an assistant helping categorize and analyze direct messages",
    "for a content creator.",
    "",
    "You must respond with a strict JSON object matching this type:",
    "",
    "type AnalysisResult = {",
    "  category: \"fan\" | \"business\" | \"spam\" | \"urgent\" | \"general\";",
    "  sentiment: \"positive\" | \"neutral\" | \"negative\";",
    "  priority: 1 | 2 | 3 | 4 | 5;",
    "  collaborationScore: number;",
    "  summary: string;",
    "  extractedInfo: {",
    "    keyFacts: string[];",
    "    requestedActions: string[];",
    "    mentionedBrands: string[];",
    "  };",
    "};",
    "",
    "Rules:",
    "- Always output valid JSON.",
    "- collaborationScore must be between 0 and 1 inclusive.",
    "- priority 1 is lowest, 5 is highest urgency.",
    "- Use empty arrays when no data is found.",
    "- summary must be 1 sentence.",
    "- If the message expresses urgent tone or critical issue, category",
    "  should be \"urgent\" and priority at least 4.",
    "- If the message mentions collaboration or sponsorship opportunities,",
    "  increase collaborationScore and priority.",
    "- spam should have low priority and collaborationScore 0.",
    "- Keep priority <= 3 for positive fan messages without urgent keywords.",
    "- Mentioned brands should include relevant organizations or people.",
].join("\n");

const buildUserPrompt = ({ message, senderProfile, creatorContext }) => {
    return [
        {
            role: "system",
            content: systemPrompt,
        },
        {
            role: "user",
            content: JSON.stringify({
                message,
                senderProfile,
                creatorContext,
            }),
        },
    ];
};

const parseAnalysis = (text) => {
    try {
        const parsed = JSON.parse(text);
        return parsed;
    } catch (error) {
        throw new Error("Failed to parse analysis JSON");
    }
};

module.exports = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "Authentication required to analyze message",
        );
    }

    const { message, senderProfile, creatorContext } = data || {};
    if (!message || typeof message !== "string") {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "Message text is required",
        );
    }

    try {
        const response = await chatCompletion({
            messages: buildUserPrompt({
                message,
                senderProfile,
                creatorContext,
            }),
            model: DEFAULT_MODEL,
            temperature: 0.2,
        });

        const choices = Array.isArray(response.choices) ? response.choices : [];
        let content = null;
        if (choices.length > 0) {
            const firstChoice = choices[0] || {};
            const messagePayload = firstChoice.message || {};
            if (typeof messagePayload.content === "string") {
                content = messagePayload.content;
            }
        }

        if (!content) {
            throw new Error("OpenAI returned empty response");
        }

        const result = parseAnalysis(content);
        const extractedInfoRaw =
            result && result.extractedInfo ? result.extractedInfo : {};

        const keyFacts = Array.isArray(extractedInfoRaw.keyFacts) ?
            extractedInfoRaw.keyFacts :
            [];
        const requestIsArray = Array.isArray(extractedInfoRaw.requestedActions);
        const requestedActions = requestIsArray ?
            extractedInfoRaw.requestedActions :
            [];
        const brandsAreArray = Array.isArray(extractedInfoRaw.mentionedBrands);
        const mentionedBrands = brandsAreArray ?
            extractedInfoRaw.mentionedBrands :
            [];

        const intentValues = Object.values(MessageIntent);
        const sentimentValues = Object.values(SentimentLabel);

        const categoryFound = intentValues.indexOf(result.category) !== -1;
        const category = categoryFound ? result.category : MessageIntent.GENERAL;

        const sentimentFound = sentimentValues.indexOf(result.sentiment) !== -1;
        const sentiment = sentimentFound ? result.sentiment : SentimentLabel.NEUTRAL;

        const priorityNumeric = Number(result.priority);
        const boundedPriority = Math.max(priorityNumeric || 1, 1);
        const clampedPriority = Math.min(boundedPriority, 5);

        const collaborationRaw = Number(result.collaborationScore);
        const boundedCollaboration = Math.max(collaborationRaw || 0, 0);
        const clampedCollaboration = Math.min(boundedCollaboration, 1);

        const summary = typeof result.summary === "string" ?
            result.summary :
            "";

        const sanitized = {
            category,
            sentiment,
            priority: clampedPriority,
            collaborationScore: clampedCollaboration,
            summary,
            extractedInfo: {
                keyFacts,
                requestedActions,
                mentionedBrands,
            },
        };

        return sanitized;
    } catch (error) {
        logError("analyzeMessage failed", error);
        throw new functions.https.HttpsError(
            "internal",
            "Failed to analyze message",
        );
    }
});

