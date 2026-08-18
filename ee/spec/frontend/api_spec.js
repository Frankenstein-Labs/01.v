import MockAdapter from 'axios-mock-adapter';
import Api from 'ee/api';
import axios from '~/lib/utils/axios_utils';
import { contentTypeMultipartFormData } from '~/lib/utils/headers';
import {
  HTTP_STATUS_CREATED,
  HTTP_STATUS_NO_CONTENT,
  HTTP_STATUS_OK,
} from '~/lib/utils/http_status';
import { VULNERABILITY_RESOLUTION_AGENT_PRIVILEGES } from '~/duo_agent_platform/constants';

describe('Api', () => {
  const dummyApiVersion = 'v3000';
  const dummyUrlRoot = '/gitlab';

  let mock;

  beforeEach(() => {
    mock = new MockAdapter(axios);
    window.gon = {
      api_version: dummyApiVersion,
      relative_url_root: dummyUrlRoot,
    };
  });

  afterEach(() => {
    mock.restore();
  });

  describe('ldapGroups', () => {
    it('returns expected data', async () => {
      const query = 'query';
      const provider = 'provider';
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/ldap/${provider}/groups.json`;
      const expectedData = [{ name: 'test' }];

      mock.onGet(expectedUrl).reply(HTTP_STATUS_OK, expectedData);
      const response = await Api.ldapGroups(query, provider);

      expect(response.data).toEqual(expectedData);
    });
  });

  describe('policy store catalogs', () => {
    it.each([
      ['getPolicyTriggers', 'triggers'],
      ['getPolicyRules', 'rules'],
      ['getPolicyActions', 'actions'],
    ])('%s fetches the policy store %s', async (method, resource) => {
      const expectedData = [{ id: `some_${resource}_id`, name: 'Some name' }];
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/security/policy_store/${resource}`;

      mock.onGet(expectedUrl).reply(HTTP_STATUS_OK, expectedData);

      const response = await Api[method]();

      expect(response.data).toEqual(expectedData);
    });
  });

  describe('getPolicyStorePolicies', () => {
    it('fetches the organization policies', async () => {
      const expectedData = [{ id: 1, name: 'Production gate' }];
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/organizations/42/security/policy_store`;

      mock.onGet(expectedUrl).reply(HTTP_STATUS_OK, expectedData);

      const response = await Api.getPolicyStorePolicies(42);

      expect(response.data).toEqual(expectedData);
    });
  });

  describe('getPolicyStorePolicy', () => {
    it('fetches one organization policy', async () => {
      const expectedData = { id: 7, name: 'Production gate' };
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/organizations/42/security/policy_store/7`;

      mock.onGet(expectedUrl).reply(HTTP_STATUS_OK, expectedData);

      const response = await Api.getPolicyStorePolicy(42, 7);

      expect(response.data).toEqual(expectedData);
    });
  });

  describe('createPolicyStorePolicy', () => {
    it('posts the policy params to the organization collection', async () => {
      const params = { name: 'Production gate', trigger_type: 'deployment_requested' };
      const expectedData = { id: 7, ...params };
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/organizations/42/security/policy_store`;

      mock.onPost(expectedUrl).reply(HTTP_STATUS_CREATED, expectedData);

      const response = await Api.createPolicyStorePolicy(42, params);

      expect(JSON.parse(mock.history.post[0].data)).toEqual(params);
      expect(response.data).toEqual(expectedData);
    });
  });

  describe('updatePolicyStorePolicy', () => {
    it('patches the policy params to the policy url', async () => {
      const params = { name: 'Renamed gate' };
      const expectedData = { id: 7, name: 'Renamed gate' };
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/organizations/42/security/policy_store/7`;

      mock.onPatch(expectedUrl).reply(HTTP_STATUS_OK, expectedData);

      const response = await Api.updatePolicyStorePolicy(42, 7, params);

      expect(JSON.parse(mock.history.patch[0].data)).toEqual(params);
      expect(response.data).toEqual(expectedData);
    });
  });

  describe('deletePolicyStorePolicy', () => {
    it('deletes one organization policy', async () => {
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/organizations/42/security/policy_store/7`;

      mock.onDelete(expectedUrl).reply(HTTP_STATUS_NO_CONTENT);

      const response = await Api.deletePolicyStorePolicy(42, 7);

      expect(response.status).toBe(HTTP_STATUS_NO_CONTENT);
    });
  });

  describe('createChildEpic', () => {
    it('calls `axios.post` using params `groupId`, `parentEpicIid` and title', async () => {
      const groupId = 'gitlab-org';
      const parentEpicId = 1;
      const title = 'Sample epic';
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/groups/${groupId}/epics`;
      const expectedRes = {
        title,
        id: 20,
        parentId: 5,
      };

      mock.onPost(expectedUrl).reply(HTTP_STATUS_OK, expectedRes);

      const { data } = await Api.createChildEpic({ groupId, parentEpicId, title });
      expect(data.title).toBe(expectedRes.title);
      expect(data.id).toBe(expectedRes.id);
      expect(data.parentId).toBe(expectedRes.parentId);
    });
  });

  describe('updateUserPreferences', () => {
    it('calls `axios.put` using params `policy_advanced_editor`', async () => {
      const advancedEditorEnabled = true;
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/user/preferences`;
      const expectedRes = {
        policy_advanced_editor: true,
      };

      mock.onPut(expectedUrl).reply(HTTP_STATUS_OK, expectedRes);

      const { data } = await Api.updateUserPreferences(advancedEditorEnabled);
      expect(data.policy_advanced_editor).toBe(expectedRes.policy_advanced_editor);
    });
  });

  describe('GroupActivityAnalytics', () => {
    const groupId = 'gitlab-org';

    describe('groupActivityMergeRequestsCount', () => {
      it('fetches the number of MRs created for a given group', () => {
        const response = { merge_requests_count: 10 };
        const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/analytics/group_activity/merge_requests_count`;

        jest.spyOn(Api, 'buildUrl').mockReturnValue(expectedUrl);
        jest.spyOn(axios, 'get');
        mock.onGet(expectedUrl).reply(HTTP_STATUS_OK, response);

        return Api.groupActivityMergeRequestsCount(groupId).then(({ data }) => {
          expect(data).toEqual(response);
          expect(axios.get).toHaveBeenCalledWith(expectedUrl, { params: { group_path: groupId } });
        });
      });
    });

    describe('groupActivityIssuesCount', () => {
      it('fetches the number of issues created for a given group', async () => {
        const response = { issues_count: 20 };
        const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/analytics/group_activity/issues_count`;

        jest.spyOn(Api, 'buildUrl').mockReturnValue(expectedUrl);
        jest.spyOn(axios, 'get');
        mock.onGet(expectedUrl).replyOnce(HTTP_STATUS_OK, response);

        const { data } = await Api.groupActivityIssuesCount(groupId);
        expect(data).toEqual(response);
        expect(axios.get).toHaveBeenCalledWith(expectedUrl, { params: { group_path: groupId } });
      });
    });

    describe('groupActivityNewMembersCount', () => {
      it('fetches the number of new members created for a given group', () => {
        const response = { new_members_count: 30 };
        const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/analytics/group_activity/new_members_count`;

        jest.spyOn(Api, 'buildUrl').mockReturnValue(expectedUrl);
        jest.spyOn(axios, 'get');
        mock.onGet(expectedUrl).reply(HTTP_STATUS_OK, response);

        return Api.groupActivityNewMembersCount(groupId).then(({ data }) => {
          expect(data).toEqual(response);
          expect(axios.get).toHaveBeenCalledWith(expectedUrl, { params: { group_path: groupId } });
        });
      });
    });
  });

  describe('changeVulnerabilityState', () => {
    it.each`
      id    | action
      ${5}  | ${'dismiss'}
      ${7}  | ${'confirm'}
      ${38} | ${'resolve'}
    `('POSTS to correct endpoint ($id, $action)', ({ id, action }) => {
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/vulnerabilities/${id}/${action}`;
      const expectedResponse = { id, action, test: 'test' };

      mock.onPost(expectedUrl).replyOnce(HTTP_STATUS_OK, expectedResponse);

      return Api.changeVulnerabilityState(id, action).then(({ data }) => {
        expect(mock.history.post).toContainEqual(expect.objectContaining({ url: expectedUrl }));
        expect(data).toEqual(expectedResponse);
      });
    });
  });

  describe('triggerVulnerabilityResolution', () => {
    it('POSTs to the duo workflows endpoint with correct parameters', async () => {
      const vulnerabilityId = 123;
      const projectId = 456;
      const aiCatalogItemConsumerId = 789;
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/ai/duo_workflows/workflows`;
      const expectedResponse = { id: 789, status: 'running' };
      const expectedPayload = {
        project_id: projectId,
        goal: vulnerabilityId.toString(),
        ai_catalog_item_consumer_id: aiCatalogItemConsumerId,
        start_workflow: true,
        workflow_definition: 'resolve_sast_vulnerability/v1',
        agent_privileges: VULNERABILITY_RESOLUTION_AGENT_PRIVILEGES,
        environment: 'web',
      };

      mock.onPost(expectedUrl).replyOnce(HTTP_STATUS_OK, expectedResponse);

      const { data } = await Api.triggerVulnerabilityResolution(
        vulnerabilityId,
        projectId,
        aiCatalogItemConsumerId,
      );

      expect(data).toEqual(expectedResponse);
      expect(mock.history.post).toContainEqual(
        expect.objectContaining({
          url: expectedUrl,
          data: JSON.stringify(expectedPayload),
        }),
      );
    });
  });

  describe('triggerFalsePositiveDetection', () => {
    it('POSTs to the duo workflows endpoint with correct parameters', async () => {
      const vulnerabilityId = 123;
      const projectId = 456;
      const aiCatalogItemConsumerId = 789;
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/ai/duo_workflows/workflows`;
      const expectedResponse = { workload: { id: 789, status: 'running' } };
      const expectedPayload = {
        project_id: projectId,
        goal: vulnerabilityId.toString(),
        ai_catalog_item_consumer_id: aiCatalogItemConsumerId,
        start_workflow: true,
        workflow_definition: 'sast_fp_detection/v1',
        agent_privileges: [1, 2, 3, 4, 5],
        environment: 'web',
      };

      mock.onPost(expectedUrl).replyOnce(HTTP_STATUS_OK, expectedResponse);

      const { data } = await Api.triggerFalsePositiveDetection(
        vulnerabilityId,
        projectId,
        aiCatalogItemConsumerId,
      );

      expect(data).toEqual(expectedResponse);
      expect(mock.history.post).toContainEqual(
        expect.objectContaining({
          url: expectedUrl,
          data: JSON.stringify(expectedPayload),
        }),
      );
    });
  });

  describe('triggerSecretDetectionFalsePositiveDetection', () => {
    it('POSTs to the duo workflows endpoint with correct parameters', async () => {
      const vulnerabilityId = 123;
      const projectId = 456;
      const aiCatalogItemConsumerId = 789;
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/ai/duo_workflows/workflows`;
      const expectedResponse = { workload: { id: 789, status: 'running' } };
      const expectedPayload = {
        project_id: projectId,
        goal: vulnerabilityId.toString(),
        ai_catalog_item_consumer_id: aiCatalogItemConsumerId,
        start_workflow: true,
        workflow_definition: 'secrets_fp_detection/v1',
        agent_privileges: [1, 2, 3, 4, 5],
        environment: 'web',
      };

      mock.onPost(expectedUrl).replyOnce(HTTP_STATUS_OK, expectedResponse);

      const { data } = await Api.triggerSecretDetectionFalsePositiveDetection(
        vulnerabilityId,
        projectId,
        aiCatalogItemConsumerId,
      );

      expect(data).toEqual(expectedResponse);
      expect(mock.history.post).toContainEqual(
        expect.objectContaining({
          url: expectedUrl,
          data: JSON.stringify(expectedPayload),
        }),
      );
    });

    it('handles null aiCatalogItemConsumerId', async () => {
      const vulnerabilityId = 123;
      const projectId = 456;
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/ai/duo_workflows/workflows`;
      const expectedResponse = { workload: { id: 789, status: 'running' } };

      mock.onPost(expectedUrl).replyOnce(HTTP_STATUS_OK, expectedResponse);

      const { data } = await Api.triggerSecretDetectionFalsePositiveDetection(
        vulnerabilityId,
        projectId,
        null,
      );

      expect(data).toEqual(expectedResponse);
      expect(mock.history.post[0].data).toContain('"ai_catalog_item_consumer_id":null');
    });

    it('includes correct workflow definition for secret detection', async () => {
      const vulnerabilityId = 123;
      const projectId = 456;
      const aiCatalogItemConsumerId = 789;
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/ai/duo_workflows/workflows`;
      const expectedResponse = { workload: { id: 789, status: 'running' } };

      mock.onPost(expectedUrl).replyOnce(HTTP_STATUS_OK, expectedResponse);

      await Api.triggerSecretDetectionFalsePositiveDetection(
        vulnerabilityId,
        projectId,
        aiCatalogItemConsumerId,
      );

      expect(mock.history.post[0].data).toContain('secrets_fp_detection/v1');
    });

    it('includes required agent privileges', async () => {
      const vulnerabilityId = 123;
      const projectId = 456;
      const aiCatalogItemConsumerId = 789;
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/ai/duo_workflows/workflows`;
      const expectedResponse = { workload: { id: 789, status: 'running' } };

      mock.onPost(expectedUrl).replyOnce(HTTP_STATUS_OK, expectedResponse);

      await Api.triggerSecretDetectionFalsePositiveDetection(
        vulnerabilityId,
        projectId,
        aiCatalogItemConsumerId,
      );

      expect(mock.history.post[0].data).toContain('[1,2,3,4,5]');
    });

    it('sets environment to web', async () => {
      const vulnerabilityId = 123;
      const projectId = 456;
      const aiCatalogItemConsumerId = 789;
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/ai/duo_workflows/workflows`;
      const expectedResponse = { workload: { id: 789, status: 'running' } };

      mock.onPost(expectedUrl).replyOnce(HTTP_STATUS_OK, expectedResponse);

      await Api.triggerSecretDetectionFalsePositiveDetection(
        vulnerabilityId,
        projectId,
        aiCatalogItemConsumerId,
      );

      expect(mock.history.post[0].data).toContain('"environment":"web"');
    });
  });

  describe('GeoSite', () => {
    let expectedUrl;
    let mockSite;

    beforeEach(() => {
      expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/geo_sites`;
    });

    describe('createGeoSite', () => {
      it('POSTs with correct action', () => {
        mockSite = {
          name: 'Mock Site',
          url: 'https://mock_site.gitlab.com',
          primary: false,
        };

        jest.spyOn(Api, 'buildUrl').mockReturnValue(expectedUrl);
        jest.spyOn(axios, 'post');
        mock.onPost(expectedUrl).replyOnce(HTTP_STATUS_CREATED, mockSite);

        return Api.createGeoSite(mockSite).then(({ data }) => {
          expect(data).toEqual(mockSite);
          expect(axios.post).toHaveBeenCalledWith(expectedUrl, mockSite);
        });
      });
    });

    describe('updateGeoSite', () => {
      it('PUTs with correct action', () => {
        mockSite = {
          id: 1,
          name: 'Mock Site',
          url: 'https://mock_site.gitlab.com',
          primary: false,
        };

        jest.spyOn(Api, 'buildUrl').mockReturnValue(expectedUrl);
        jest.spyOn(axios, 'put');
        mock.onPut(`${expectedUrl}/${mockSite.id}`).replyOnce(HTTP_STATUS_CREATED, mockSite);

        return Api.updateGeoSite(mockSite).then(({ data }) => {
          expect(data).toEqual(mockSite);
          expect(axios.put).toHaveBeenCalledWith(`${expectedUrl}/${mockSite.id}`, mockSite);
        });
      });
    });

    describe('removeGeoSite', () => {
      it('DELETES with correct ID', () => {
        mockSite = {
          id: 1,
        };

        jest.spyOn(Api, 'buildUrl').mockReturnValue(`${expectedUrl}/${mockSite.id}`);
        jest.spyOn(axios, 'delete');
        mock.onDelete(`${expectedUrl}/${mockSite.id}`).replyOnce(HTTP_STATUS_OK, {});

        return Api.removeGeoSite(mockSite.id).then(() => {
          expect(axios.delete).toHaveBeenCalledWith(`${expectedUrl}/${mockSite.id}`);
        });
      });
    });
  });

  describe('Project analytics: deployment frequency', () => {
    const projectPath = 'test/project';
    const encodedProjectPath = encodeURIComponent(projectPath);
    const params = { environment: 'production' };
    const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/projects/${encodedProjectPath}/analytics/deployment_frequency`;

    describe('deploymentFrequencies', () => {
      it('GETs the right url', async () => {
        mock.onGet(expectedUrl, { params }).replyOnce(HTTP_STATUS_OK, []);

        const { data } = await Api.deploymentFrequencies(projectPath, params);

        expect(data).toEqual([]);
      });
    });
  });

  describe('Issue metric images', () => {
    const projectId = 1;
    const issueIid = '2';
    const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/projects/${projectId}/issues/${issueIid}/metric_images`;

    describe('fetchIssueMetricImages', () => {
      it('fetches a list of images', async () => {
        jest.spyOn(axios, 'get');
        mock.onGet(expectedUrl).replyOnce(HTTP_STATUS_OK, []);

        await Api.fetchIssueMetricImages({ issueIid, id: projectId }).then(({ data }) => {
          expect(data).toEqual([]);
          expect(axios.get).toHaveBeenCalled();
        });
      });
    });

    describe('uploadIssueMetricImage', () => {
      const file = 'mock file';
      const url = 'mock url';
      const urlText = 'mock urlText';

      it('uploads an image', async () => {
        jest.spyOn(axios, 'post');
        mock.onPost(expectedUrl).replyOnce(HTTP_STATUS_OK, {});

        await Api.uploadIssueMetricImage({ issueIid, id: projectId, file, url, urlText }).then(
          ({ data }) => {
            expect(data).toEqual({});
            expect(axios.post.mock.calls[0][2]).toEqual({
              headers: { ...contentTypeMultipartFormData },
            });
          },
        );
      });
    });
  });

  describe('deployment approvals', () => {
    const projectId = 1;
    const deploymentId = 2;
    const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/projects/${projectId}/deployments/${deploymentId}/approval`;
    const representedAs = 'Maintainers';
    const comment = 'comment';

    it('sends an approval when approve is true', async () => {
      mock
        .onPost(expectedUrl, { status: 'approved', represented_as: representedAs, comment })
        .replyOnce(HTTP_STATUS_OK);

      await Api.deploymentApproval({
        id: projectId,
        deploymentId,
        approve: true,
        representedAs,
        comment,
      });

      expect(mock.history.post).toHaveLength(1);
      expect(mock.history.post[0].data).toBe(
        JSON.stringify({ status: 'approved', represented_as: representedAs, comment }),
      );
    });

    it('sends a rejection when approve is false', async () => {
      mock
        .onPost(expectedUrl, { status: 'rejected', represented_as: representedAs, comment })
        .replyOnce(HTTP_STATUS_OK);

      await Api.deploymentApproval({
        id: projectId,
        deploymentId,
        approve: false,
        representedAs,
        comment,
      });

      expect(mock.history.post).toHaveLength(1);
      expect(mock.history.post[0].data).toBe(
        JSON.stringify({ status: 'rejected', represented_as: representedAs, comment }),
      );
    });
  });

  describe('validatePaymentMethod', () => {
    it('submits the custom value stream data', () => {
      const response = {};
      const expectedUrl = '/gitlab/-/subscriptions/validate_payment_method';
      mock.onPost(expectedUrl).reply(HTTP_STATUS_OK, response);

      return Api.validatePaymentMethod('id', 'user_id').then((res) => {
        expect(res.data).toEqual(response);
        expect(res.config.url).toEqual(expectedUrl);
      });
    });
  });

  describe('updateCompliancePolicySettings', () => {
    it('updates compliance and policy settings', async () => {
      const settings = { csp_namespace_id: 123 };
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/admin/security/compliance_policy_settings`;
      const expectedResponse = { success: true };

      mock.onPut(expectedUrl).reply(HTTP_STATUS_OK, expectedResponse);

      const { data } = await Api.updateCompliancePolicySettings(settings);

      expect(data).toEqual(expectedResponse);
      expect(mock.history.put).toContainEqual(
        expect.objectContaining({
          url: expectedUrl,
          data: JSON.stringify(settings),
        }),
      );
    });

    it('handles null csp_namespace_id', async () => {
      const settings = { csp_namespace_id: null };
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/admin/security/compliance_policy_settings`;
      const expectedResponse = { success: true };

      mock.onPut(expectedUrl).reply(HTTP_STATUS_OK, expectedResponse);

      const { data } = await Api.updateCompliancePolicySettings(settings);

      expect(data).toEqual(expectedResponse);
      expect(mock.history.put).toContainEqual(
        expect.objectContaining({
          url: expectedUrl,
          data: JSON.stringify(settings),
        }),
      );
    });

    it('handles empty settings object', async () => {
      const settings = {};
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/admin/security/compliance_policy_settings`;
      const expectedResponse = { success: true };

      mock.onPut(expectedUrl).reply(HTTP_STATUS_OK, expectedResponse);

      const { data } = await Api.updateCompliancePolicySettings(settings);

      expect(data).toEqual(expectedResponse);
      expect(mock.history.put).toContainEqual(
        expect.objectContaining({
          url: expectedUrl,
          data: JSON.stringify(settings),
        }),
      );
    });
  });

  describe('protectedEnvironments', () => {
    it('fetches all protected environments for projects', () => {
      const response = [{ name: 'staging ' }];
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/projects/1/protected_environments/`;
      mock.onGet(expectedUrl).reply(HTTP_STATUS_OK, response);

      return Api.protectedEnvironments(1, 'projects').then(({ data, config }) => {
        expect(data).toEqual(response);
        expect(config.url).toEqual(expectedUrl);
      });
    });

    it('fetches all protected environments for groups', () => {
      const response = [{ name: 'staging ' }];
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/groups/1/protected_environments/`;
      mock.onGet(expectedUrl).reply(HTTP_STATUS_OK, response);

      return Api.protectedEnvironments(1, 'groups').then(({ data, config }) => {
        expect(data).toEqual(response);
        expect(config.url).toEqual(expectedUrl);
      });
    });
  });

  describe('updateProtectedEnvironment', () => {
    it('puts changes to a protected environment for projects', () => {
      const response = { name: 'staging' };
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/projects/1/protected_environments/staging`;
      mock.onPut(expectedUrl, response).reply(HTTP_STATUS_OK, response);

      return Api.updateProtectedEnvironment(1, 'projects', response).then(({ data, config }) => {
        expect(data).toEqual(response);
        expect(config.url).toBe(expectedUrl);
      });
    });

    it('puts changes to a protected environment for groups', () => {
      const response = { name: 'staging' };
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/groups/1/protected_environments/staging`;
      mock.onPut(expectedUrl, response).reply(HTTP_STATUS_OK, response);

      return Api.updateProtectedEnvironment(1, 'groups', response).then(({ data, config }) => {
        expect(data).toEqual(response);
        expect(config.url).toBe(expectedUrl);
      });
    });
  });

  describe('deleteProtectedEnvironment', () => {
    it('deletes a protected environment for projects', () => {
      const environment = { name: 'staging' };
      const response = {};
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/projects/1/protected_environments/staging`;
      mock.onDelete(expectedUrl, environment).reply(HTTP_STATUS_OK, response);

      return Api.deleteProtectedEnvironment(1, 'projects', environment).then(({ data, config }) => {
        expect(data).toEqual(response);
        expect(config.url).toBe(expectedUrl);
      });
    });

    it('deletes a protected environment for groups', () => {
      const environment = { name: 'staging' };
      const response = {};
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/groups/1/protected_environments/staging`;
      mock.onDelete(expectedUrl, environment).reply(HTTP_STATUS_OK, response);

      return Api.deleteProtectedEnvironment(1, 'groups', environment).then(({ data, config }) => {
        expect(data).toEqual(response);
        expect(config.url).toBe(expectedUrl);
      });
    });
  });

  describe('AI endpoints', () => {
    const model = 'test-model';
    const prompt = 'test-prompt';
    const msg = 'foo bar';
    const rest = { max_tokens: 50, temperature: 0.5 };

    describe('requestAICompletions', () => {
      it('queries the completions AI endpoint', () => {
        const expectedUrl = Api.buildUrl(Api.aiCompletionsPath);
        const expectedResponse = { choices: { text: msg } };
        mock.onPost(expectedUrl).reply(HTTP_STATUS_OK, expectedResponse);

        return Api.requestAICompletions({ model, prompt, ...rest }).then((res) => {
          expect(res.data).toEqual(expectedResponse);
          expect(res.config.url).toEqual(expectedUrl);
        });
      });
    });

    describe('requestAIEmbeddings', () => {
      it('queries the completions AI endpoint', () => {
        const expectedUrl = Api.buildUrl(Api.aiEmbeddingsPath);
        const expectedResponse = { data: [{ embedding: [msg] }] };
        mock.onPost(expectedUrl).reply(HTTP_STATUS_OK, expectedResponse);

        return Api.requestAIEmbeddings({ model, input: prompt, ...rest }).then((res) => {
          expect(res.data).toEqual(expectedResponse);
          expect(res.config.url).toEqual(expectedUrl);
        });
      });
    });

    describe('requestAIChat', () => {
      it('queries the completions AI endpoint', () => {
        const expectedUrl = Api.buildUrl(Api.aiChatPath);
        const expectedResponse = { choices: { message: msg } };
        mock.onPost(expectedUrl).reply(HTTP_STATUS_OK, expectedResponse);

        return Api.requestAIChat({ model, messages: [msg], ...rest }).then((res) => {
          expect(res.data).toEqual(expectedResponse);
          expect(res.config.url).toEqual(expectedUrl);
        });
      });
    });

    describe('requestTanukiBotResponse', () => {
      it('sends a POST request to the tanuki bot endpoint', () => {
        const expectedUrl = Api.buildUrl(Api.tanukiBotAskPath);
        const expectedResponse = { msg };
        mock.onPost(expectedUrl).reply(HTTP_STATUS_OK, expectedResponse);

        return Api.requestTanukiBotResponse(msg).then((res) => {
          expect(res.data).toEqual(expectedResponse);
          expect(res.config.url).toEqual(expectedUrl);
        });
      });
    });
  });
});
