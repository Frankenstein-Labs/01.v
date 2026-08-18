import MockAdapter from 'axios-mock-adapter';
import * as GroupsApi from 'ee/api/groups_api';
import { DEFAULT_PER_PAGE } from '~/api';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_OK } from '~/lib/utils/http_status';

describe('GroupsApi', () => {
  const dummyApiVersion = 'v3000';
  const dummyUrlRoot = '/gitlab';
  const namespaceId = 1000;
  const memberId = 2;
  const groupId = 10;

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

  describe('Billable members list', () => {
    describe('fetchBillableGroupMembersList', () => {
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/groups/${namespaceId}/billable_members`;

      it('GETs the right url', async () => {
        jest.spyOn(axios, 'get');
        mock.onGet(expectedUrl).replyOnce(HTTP_STATUS_OK, []);

        const { data } = await GroupsApi.fetchBillableGroupMembersList(namespaceId);

        expect(data).toEqual([]);
        expect(axios.get).toHaveBeenCalledWith(expectedUrl, {
          params: { page: 1, per_page: DEFAULT_PER_PAGE },
        });
      });
    });

    describe('fetchBillableGroupMemberMemberships', () => {
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/groups/${namespaceId}/billable_members/${memberId}/memberships`;

      it('fetches memberships for the member', async () => {
        jest.spyOn(axios, 'get');
        mock.onGet(expectedUrl).replyOnce(HTTP_STATUS_OK, []);

        const { data } = await GroupsApi.fetchBillableGroupMemberMemberships(namespaceId, memberId);

        expect(data).toEqual([]);
        expect(axios.get).toHaveBeenCalledWith(expectedUrl);
      });
    });

    describe('fetchBillableGroupMemberIndirectMemberships', () => {
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/groups/${namespaceId}/billable_members/${memberId}/indirect`;

      it('fetches indirect memberships for the member', async () => {
        jest.spyOn(axios, 'get');
        mock.onGet(expectedUrl).replyOnce(HTTP_STATUS_OK, []);

        const { data } = await GroupsApi.fetchBillableGroupMemberIndirectMemberships(
          namespaceId,
          memberId,
        );

        expect(data).toEqual([]);
        expect(axios.get).toHaveBeenCalledWith(expectedUrl);
      });
    });

    describe('removeBillableMemberFromGroup', () => {
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/groups/${namespaceId}/billable_members/${memberId}`;

      it('removes a billable member from a group', async () => {
        jest.spyOn(axios, 'delete');
        mock.onDelete(expectedUrl).replyOnce(HTTP_STATUS_OK, []);

        const { data } = await GroupsApi.removeBillableMemberFromGroup(namespaceId, memberId);

        expect(data).toEqual([]);
        expect(axios.delete).toHaveBeenCalledWith(expectedUrl);
      });
    });
  });

  describe('updateGroupSettings', () => {
    const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/groups/${namespaceId}`;

    beforeEach(() => {
      jest.spyOn(axios, 'put');
      mock.onPut(expectedUrl).replyOnce(HTTP_STATUS_OK, {});
    });

    it('sends PUT request to the correct URL with the correct payload', async () => {
      const setting = { setting_a: 'a', setting_b: 'b' };
      const { data } = await GroupsApi.updateGroupSettings(namespaceId, setting);

      expect(data).toEqual({});
      expect(axios.put).toHaveBeenCalledWith(expectedUrl, setting);
    });
  });

  describe('deleteGroup', () => {
    beforeEach(() => {
      jest.spyOn(axios, 'delete');
    });

    describe('without params', () => {
      it('deletes to the correct URL', () => {
        const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/groups/${groupId}`;

        mock.onDelete(expectedUrl).replyOnce(HTTP_STATUS_OK);

        return GroupsApi.deleteGroup(groupId).then(() => {
          expect(axios.delete).toHaveBeenCalledWith(expectedUrl, { params: undefined });
        });
      });
    });

    describe('with params', () => {
      it('deletes to the correct URL', () => {
        const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/groups/${groupId}`;

        mock.onDelete(expectedUrl).replyOnce(HTTP_STATUS_OK);

        return GroupsApi.deleteGroup(groupId, { testParam: true }).then(() => {
          expect(axios.delete).toHaveBeenCalledWith(expectedUrl, { params: { testParam: true } });
        });
      });
    });
  });

  describe('subscriptionsCreateGroup', () => {
    const expectedUrl = '/gitlab/-/subscriptions/groups';

    beforeEach(() => {
      jest.spyOn(axios, 'post');
      mock.onPost(expectedUrl).replyOnce(HTTP_STATUS_OK, {});
    });

    it('sends POST request to the correct URL with the correct payload', async () => {
      const params = { name: 'Test Group', path: 'test-group' };
      const { data } = await GroupsApi.subscriptionsCreateGroup(params);

      expect(data).toEqual({});
      expect(axios.post).toHaveBeenCalledWith(expectedUrl, params);
    });
  });
});
