import MockAdapter from 'axios-mock-adapter';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_INTERNAL_SERVER_ERROR, HTTP_STATUS_OK } from '~/lib/utils/http_status';
import { EMPTY_CATALOGS, fetchCatalogs } from 'ee/policy_store/catalog/catalogs';
import { ACTIONS } from 'ee/policy_store/catalog/actions';
import { RULES } from 'ee/policy_store/catalog/rules';
import { TRIGGERS } from 'ee/policy_store/catalog/triggers';

jest.mock('~/sentry/sentry_browser_wrapper');

const TRIGGERS_URL = '/api/v4/security/policy_store/triggers';
const RULES_URL = '/api/v4/security/policy_store/rules';
const ACTIONS_URL = '/api/v4/security/policy_store/actions';

describe('policy store catalogs', () => {
  let mock;

  beforeEach(() => {
    window.gon = { api_version: 'v4' };
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    mock.restore();
  });

  // One handler per URL: axios-mock-adapter matches the first registered handler.
  const replyAll = ({
    triggers = [{ id: 'deployment_requested', name: 'Deployment' }],
    rules = [{ id: 'custom', name: 'Custom' }],
    actions = [{ id: 'block', name: 'Block' }],
  } = {}) => {
    mock.onGet(TRIGGERS_URL).reply(HTTP_STATUS_OK, triggers);
    mock.onGet(RULES_URL).reply(HTTP_STATUS_OK, rules);
    mock.onGet(ACTIONS_URL).reply(HTTP_STATUS_OK, actions);
  };

  it('exposes empty catalogs for consumers to start from', () => {
    expect(EMPTY_CATALOGS).toEqual({ triggers: [], rules: [], actions: [] });
  });

  it('presents an id the local catalog knows with its full local entry', async () => {
    replyAll({
      rules: [
        { id: 'calendar', name: 'Calendar' },
        { id: 'environment', name: 'Environment' },
      ],
    });

    const { catalogs, failedCatalogs } = await fetchCatalogs();

    expect(failedCatalogs).toEqual([]);
    expect(catalogs.triggers).toEqual([TRIGGERS.find(({ id }) => id === 'deployment_requested')]);
    expect(catalogs.rules).toEqual([
      RULES.find(({ id }) => id === 'calendar'),
      RULES.find(({ id }) => id === 'environment'),
    ]);
    expect(catalogs.actions).toEqual([ACTIONS.find(({ id }) => id === 'block')]);
  });

  it('presents an unknown id as a minimal entry named by the API', async () => {
    replyAll({ rules: [{ id: 'holiday', name: 'Holiday' }] });

    const { catalogs } = await fetchCatalogs();

    expect(catalogs.rules).toEqual([
      { id: 'holiday', label: 'Holiday', description: '', icon: 'question-o', fields: [] },
    ]);
  });

  it('drops entries without an id, which cannot serve as the wire value', async () => {
    replyAll({ rules: [{}, { name: 'No id' }, { id: 'custom', name: 'Custom' }, null] });

    const { catalogs } = await fetchCatalogs();

    expect(catalogs.rules).toEqual([RULES.find(({ id }) => id === 'custom')]);
  });

  it('names a failing catalog and empties it while the others keep their entries', async () => {
    replyAll();
    mock.onGet(TRIGGERS_URL).reply(HTTP_STATUS_INTERNAL_SERVER_ERROR);

    const { catalogs, failedCatalogs } = await fetchCatalogs();

    expect(failedCatalogs).toEqual(['triggers']);
    expect(catalogs.triggers).toEqual([]);
    expect(catalogs.rules).toEqual([RULES.find(({ id }) => id === 'custom')]);
    expect(catalogs.actions).toEqual([ACTIONS.find(({ id }) => id === 'block')]);
    expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error), {
      tags: { policyStoreCatalog: 'triggers' },
    });
  });

  it('names every failing catalog when several requests fail', async () => {
    replyAll();
    mock.onGet(TRIGGERS_URL).reply(HTTP_STATUS_INTERNAL_SERVER_ERROR);
    mock.onGet(ACTIONS_URL).networkError();

    const { failedCatalogs } = await fetchCatalogs();

    expect(failedCatalogs).toEqual(['triggers', 'actions']);
  });

  it('treats an empty catalog as failed, since no policy can be built from it', async () => {
    replyAll({ rules: [] });

    const { failedCatalogs } = await fetchCatalogs();

    expect(failedCatalogs).toEqual(['rules']);
    expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error), {
      tags: { policyStoreCatalog: 'rules' },
    });
  });

  it('treats a catalog with only unusable entries as failed', async () => {
    replyAll({ actions: [{}, { name: 'No id' }] });

    const { failedCatalogs } = await fetchCatalogs();

    expect(failedCatalogs).toEqual(['actions']);
  });

  it('treats a malformed payload as failed', async () => {
    replyAll({ triggers: { not: 'an array' } });

    const { failedCatalogs } = await fetchCatalogs();

    expect(failedCatalogs).toEqual(['triggers']);
    expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error), {
      tags: { policyStoreCatalog: 'triggers' },
    });
  });
});
