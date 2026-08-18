import MockAdapter from 'axios-mock-adapter';
import axios from '~/lib/utils/axios_utils';
import {
  HTTP_STATUS_BAD_REQUEST,
  HTTP_STATUS_CREATED,
  HTTP_STATUS_INTERNAL_SERVER_ERROR,
  HTTP_STATUS_NO_CONTENT,
  HTTP_STATUS_NOT_FOUND,
  HTTP_STATUS_OK,
} from '~/lib/utils/http_status';
import {
  fetchPolicies,
  fetchPolicy,
  createPolicy,
  updatePolicy,
  deletePolicy,
} from 'ee/policy_store/policies';

const POLICIES_URL = '/api/v4/organizations/1/security/policy_store';
const TRIGGERS_URL = '/api/v4/security/policy_store/triggers';
const POLICY_URL = '/api/v4/organizations/1/security/policy_store/7';

describe('policy store policies', () => {
  let mock;

  beforeEach(() => {
    window.gon = { api_version: 'v4' };
    mock = new MockAdapter(axios);
    mock.onGet(TRIGGERS_URL).reply(HTTP_STATUS_OK, [
      { id: 'deployment_requested', name: 'Deployment' },
      { id: 'merge_requested', name: 'Merge Request' },
    ]);
  });

  afterEach(() => {
    mock.restore();
  });

  const apiPolicy = {
    id: 7,
    name: 'Production gate',
    description: 'Gates production deployments',
    trigger_type: 'deployment_requested',
    rules: [{ type: 'custom', value: 'package governance' }],
    actions: [{ type: 'block' }],
    policy_scope: { projects: { including: [1, 2, 3] } },
    mode: 'enforce',
    lifecycle_state: 'active',
    updated_at: '2026-08-11T10:00:00Z',
  };

  it('maps the API policy for the list and the editor', async () => {
    mock.onGet(POLICIES_URL).reply(HTTP_STATUS_OK, [apiPolicy]);

    const policies = await fetchPolicies(1);

    expect(policies[0]).toMatchObject({
      id: 7,
      name: 'Production gate',
      type: 'Deployment',
      trigger_type: 'deployment_requested',
      status: 'active',
      scopedProjectsCount: 3,
      mode: 'enforce',
    });
    expect(policies[0]).not.toHaveProperty('scope');
  });

  it('labels a trigger the local catalog does not know with the API-provided name', async () => {
    mock
      .onGet(POLICIES_URL)
      .reply(HTTP_STATUS_OK, [{ ...apiPolicy, trigger_type: 'merge_requested' }]);

    const policies = await fetchPolicies(1);

    expect(policies[0].type).toBe('Merge Request');
  });

  it('falls back to the raw trigger type when no catalog knows it', async () => {
    mock
      .onGet(POLICIES_URL)
      .reply(HTTP_STATUS_OK, [{ ...apiPolicy, trigger_type: 'unknown_trigger' }]);

    const policies = await fetchPolicies(1);

    expect(policies[0].type).toBe('unknown_trigger');
  });

  it('still resolves the policies when the triggers catalog request fails', async () => {
    mock.onGet(TRIGGERS_URL).reply(HTTP_STATUS_INTERNAL_SERVER_ERROR);
    mock
      .onGet(POLICIES_URL)
      .reply(HTTP_STATUS_OK, [{ ...apiPolicy, trigger_type: 'merge_requested' }]);

    const policies = await fetchPolicies(1);

    expect(policies[0].type).toBe('merge_requested');
  });

  it('counts no scoped projects when the policy scope has none', async () => {
    mock.onGet(POLICIES_URL).reply(HTTP_STATUS_OK, [{ ...apiPolicy, policy_scope: null }]);

    const policies = await fetchPolicies(1);

    expect(policies[0].scopedProjectsCount).toBe(0);
  });

  it('rejects with the request error when the API fails', async () => {
    mock.onGet(POLICIES_URL).reply(HTTP_STATUS_INTERNAL_SERVER_ERROR);

    await expect(fetchPolicies(1)).rejects.toThrow();
  });

  describe('fetchPolicy', () => {
    it('maps the API policy the same way as the list', async () => {
      mock.onGet(POLICY_URL).reply(HTTP_STATUS_OK, apiPolicy);

      const policy = await fetchPolicy(1, 7);

      expect(policy).toMatchObject({
        id: 7,
        name: 'Production gate',
        type: 'Deployment',
        trigger_type: 'deployment_requested',
        status: 'active',
        scopedProjectsCount: 3,
      });
    });

    it('rejects with the request error when the policy is not found', async () => {
      mock.onGet(POLICY_URL).reply(HTTP_STATUS_NOT_FOUND);

      await expect(fetchPolicy(1, 7)).rejects.toThrow();
    });
  });

  describe('createPolicy', () => {
    const params = {
      name: 'Production gate',
      trigger_type: 'deployment_requested',
      rules: [{ type: 'custom', value: 'package governance' }],
    };

    it('posts the params and maps the created policy like the list', async () => {
      mock.onPost(POLICIES_URL).reply(HTTP_STATUS_CREATED, apiPolicy);

      const policy = await createPolicy(1, params);

      expect(JSON.parse(mock.history.post[0].data)).toEqual(params);
      expect(policy).toMatchObject({ id: 7, type: 'Deployment', status: 'active' });
    });

    it('rejects with the request error when the params are invalid', async () => {
      mock.onPost(POLICIES_URL).reply(HTTP_STATUS_BAD_REQUEST, { message: 'name is invalid' });

      await expect(createPolicy(1, params)).rejects.toThrow();
    });
  });

  describe('updatePolicy', () => {
    const params = { name: 'Renamed gate' };

    it('patches the params and maps the updated policy like the list', async () => {
      mock.onPatch(POLICY_URL).reply(HTTP_STATUS_OK, { ...apiPolicy, name: 'Renamed gate' });

      const policy = await updatePolicy(1, 7, params);

      expect(JSON.parse(mock.history.patch[0].data)).toEqual(params);
      expect(policy).toMatchObject({ id: 7, name: 'Renamed gate', type: 'Deployment' });
    });

    it('rejects with the request error when the API fails', async () => {
      mock.onPatch(POLICY_URL).reply(HTTP_STATUS_INTERNAL_SERVER_ERROR);

      await expect(updatePolicy(1, 7, params)).rejects.toThrow();
    });
  });

  describe('deletePolicy', () => {
    it('deletes the policy', async () => {
      mock.onDelete(POLICY_URL).reply(HTTP_STATUS_NO_CONTENT);

      await deletePolicy(1, 7);

      expect(mock.history.delete).toHaveLength(1);
      expect(mock.history.delete[0].url).toBe(POLICY_URL);
    });

    it('rejects with the request error when the API fails', async () => {
      mock.onDelete(POLICY_URL).reply(HTTP_STATUS_INTERNAL_SERVER_ERROR);

      await expect(deletePolicy(1, 7)).rejects.toThrow();
    });
  });
});
