import MockAdapter from 'axios-mock-adapter';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_OK } from '~/lib/utils/http_status';
import { resumeWorkflow, cancelWorkflow } from 'ee/api/duo_agent_platform_api';

const mockApiVersion = 'v4';
const mockUrlRoot = '/gitlab';
const mockWorkflowId = '123';

describe('DuoAgentPlatformApi', () => {
  let mock;

  beforeEach(() => {
    mock = new MockAdapter(axios);
    window.gon = {
      api_version: mockApiVersion,
      relative_url_root: mockUrlRoot,
    };
  });

  afterEach(() => {
    mock.restore();
  });

  describe('resumeWorkflow', () => {
    const resumeUrl = `${mockUrlRoot}/api/${mockApiVersion}/ai/duo_workflows/workflows/${mockWorkflowId}/resume`;

    it('makes POST request with humanApproval true', async () => {
      mock.onPost(resumeUrl).reply(HTTP_STATUS_OK, { success: true });

      await resumeWorkflow(mockWorkflowId, { humanApproval: true });

      expect(mock.history.post[0].url).toBe(resumeUrl);
      expect(JSON.parse(mock.history.post[0].data)).toEqual({ human_approval: true });
    });

    it('makes POST request with humanMessage', async () => {
      mock.onPost(resumeUrl).reply(HTTP_STATUS_OK, { success: true });

      await resumeWorkflow(mockWorkflowId, {
        humanApproval: false,
        humanMessage: 'Change the plan',
      });

      expect(JSON.parse(mock.history.post[0].data)).toEqual({
        human_approval: false,
        human_message: 'Change the plan',
      });
    });
  });

  describe('cancelWorkflow', () => {
    const cancelUrl = `${mockUrlRoot}/api/${mockApiVersion}/ai/duo_workflows/workflows/${mockWorkflowId}`;

    it('makes PATCH request with stop event', async () => {
      mock.onPatch(cancelUrl).reply(HTTP_STATUS_OK, { success: true });

      await cancelWorkflow(mockWorkflowId);

      expect(mock.history.patch[0].url).toBe(cancelUrl);
      expect(JSON.parse(mock.history.patch[0].data)).toEqual({ status_event: 'stop' });
    });
  });
});
