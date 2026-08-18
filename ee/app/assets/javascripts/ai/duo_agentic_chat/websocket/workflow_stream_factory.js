import { MAX_WS_RETRIES, WS_RETRY_DELAY_MS } from '../constants';
import { WorkflowStream } from './workflow_stream';
import { RetryableWorkflowStream } from './retryable_workflow_stream';

export class WorkflowStreamFactory {
  #stream;

  constructor({ maxRetries = MAX_WS_RETRIES, retryDelay = WS_RETRY_DELAY_MS } = {}) {
    this.#stream = new RetryableWorkflowStream(new WorkflowStream(), {
      retryDelay,
      maxRetries,
    });
  }

  getWorkflowStream() {
    return this.#stream;
  }
}

export const workflowStreamFactory = new WorkflowStreamFactory();
