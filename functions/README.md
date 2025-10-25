# MessageAI Cloud Functions

This directory contains the Firebase Cloud Functions that power MessageAI's backend automation and AI workflows.

## Environment Configuration

Sensitive configuration values are managed via `firebase functions:config:set`.

### OpenAI Credentials

The AI features require OpenAI credentials to be provided through the Firebase Functions config:

```bash
firebase functions:config:set \
  openai.apikey="YOUR_OPENAI_API_KEY" \
  openai.api_base_url="https://api.openai.com/v1" # optional override
```

- `openai.apikey` (required): API key for accessing OpenAI.
- `openai.api_base_url` (optional): Custom base URL if using a proxy or Azure instance.

Deploy the updated runtime config after setting or changing values:

```bash
firebase deploy --only functions
```

## Project Structure

- `index.js`: Cloud Functions entry point exporting handlers.
- `src/app.js`: Initializes Firebase Admin SDK and exports shared instances.
- `src/config.js`: Wrapper utilities for accessing runtime configuration.
- `src/logger.js`: Centralized logging helpers built on `functions.logger`.
- `src/openai-client.js`: Lazily instantiated OpenAI SDK client.
- `src/functions/`: Directory containing individual Cloud Function implementations.

## Development Notes

1. Install dependencies:
   ```bash
   npm install
   ```
2. Run lint before deployment (also executed automatically by `firebase.json` predeploy hook):
   ```bash
   npm run lint
   ```
3. Use the Firebase emulator for local development:
   ```bash
   npm run serve
   ```

Ensure secrets are not committed to source control. Use Firebase config or local `.env` files ignored by git for development credentials.


