import MockAdapter from 'axios-mock-adapter';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_OK } from '~/lib/utils/http_status';
import { getMemberRoles } from 'ee/projects/settings/api/access_dropdown_api';

describe('getMemberRoles', () => {
  let mock;

  beforeEach(() => {
    mock = new MockAdapter(axios);
    window.gon = { relative_url_root: '', api_version: 'v4' };
  });

  afterEach(() => {
    mock.restore();
    delete window.gon;
  });

  it('fetches member roles for the given namespace', () => {
    const namespaceId = 123;
    const apiVersion = 'v4';
    const apiResponse = [{ id: 1, name: 'Lead Developer', base_access_level: 30 }];
    const expectedUrl = `/api/${apiVersion}/groups/${namespaceId}/member_roles`;

    mock.onGet(expectedUrl).replyOnce(HTTP_STATUS_OK, apiResponse);

    return getMemberRoles(namespaceId).then(({ data }) => {
      expect(data).toEqual(apiResponse);
    });
  });
  it('rejects when namespaceId is missing', () => {
    return expect(getMemberRoles()).rejects.toThrow('namespaceId is required');
  });
});
