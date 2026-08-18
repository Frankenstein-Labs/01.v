import MockAdapter from 'axios-mock-adapter';
import models from 'test_fixtures/api/admin/data_management/snippet_repositories.json';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_OK } from '~/lib/utils/http_status';
import {
  putModelAction,
  getModels,
  putBulkModelAction,
  getModel,
} from 'ee/api/data_management_api';

const mockApiVersion = 'v4';
const mockUrlRoot = '/gitlab';

describe('DataManagementApp', () => {
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

  describe('getModels', () => {
    it('calls correct URL and returns expected response', async () => {
      const model = 'model';
      const expectedUrl = `${mockUrlRoot}/api/${mockApiVersion}/admin/data_management/${model}`;

      mock.onGet(expectedUrl).reply(HTTP_STATUS_OK, { data: models });

      await expect(getModels(model)).resolves.toMatchObject({ data: { data: models } });
    });

    it('passes params to request', async () => {
      const model = 'snippet_repository';
      const params = { page: 1, per_page: 20, checksum_state: 'verified' };
      const expectedUrl = `${mockUrlRoot}/api/${mockApiVersion}/admin/data_management/${model}`;

      mock.onGet(expectedUrl).reply(HTTP_STATUS_OK, { data: models });

      await getModels(model, params);

      expect(mock.history.get[0].params).toEqual(params);
    });
  });

  describe('getModel', () => {
    it('calls correct URL and returns expected response', async () => {
      const model = 'model';
      const id = 1;
      const expectedUrl = `${mockUrlRoot}/api/${mockApiVersion}/admin/data_management/${model}/${id}`;

      const [data] = models;
      mock.onGet(expectedUrl).reply(HTTP_STATUS_OK, { data });

      await expect(getModel(model, id)).resolves.toMatchObject({ data: { data } });
    });
  });

  describe('putModelAction', () => {
    it('calls correct URL and returns expected response', async () => {
      const model = 'model';
      const recordIdentifier = 1;
      const action = 'action';

      const expectedUrl = `${mockUrlRoot}/api/${mockApiVersion}/admin/data_management/${model}/${recordIdentifier}/${action}`;

      mock.onPut(expectedUrl).reply(HTTP_STATUS_OK, { data: models });

      await expect(putModelAction(model, recordIdentifier, action)).resolves.toMatchObject({
        data: { data: models },
      });
    });
  });

  describe('putBulkModelAction', () => {
    it('calls correct URL and returns expected response', async () => {
      const model = 'model';
      const action = 'action';

      const expectedUrl = `${mockUrlRoot}/api/${mockApiVersion}/admin/data_management/${model}/${action}`;

      mock.onPut(expectedUrl).reply(HTTP_STATUS_OK, { data: 'model' });

      await expect(putBulkModelAction(model, action)).resolves.toMatchObject({
        data: { data: 'model' },
      });
    });
  });
});
