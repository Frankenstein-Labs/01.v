import { setupServer } from 'msw/node';
import { buildHandlers, featureHandlers, restEndpoints } from './handlers';

// Setup requests interception in Node
export const server = setupServer(...buildHandlers(featureHandlers, restEndpoints));
