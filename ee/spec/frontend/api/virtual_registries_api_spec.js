import MockAdapter from 'axios-mock-adapter';
import * as VirtualRegistryApi from 'ee/api/virtual_registries_api';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_OK } from '~/lib/utils/http_status';

const dummyApiVersion = 'v3000';
const dummyUrlRoot = '/gitlab';

describe('VirtualRegistriesApi', () => {
  let mock;

  beforeEach(() => {
    mock = new MockAdapter(axios);
    window.gon = {
      api_version: dummyApiVersion,
      relative_url_root: dummyUrlRoot,
    };
    jest.spyOn(axios, 'get');
    jest.spyOn(axios, 'delete');
    jest.spyOn(axios, 'post');
  });

  afterEach(() => {
    mock.restore();
  });

  describe('updateMavenUpstream', () => {
    it('updates the maven upstream', () => {
      const requestPath = 'virtual_registries/packages/maven/upstreams';
      const upstreamId = 1;
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/${requestPath}/${upstreamId}`;
      const expectedData = {
        id: upstreamId,
        name: 'new name',
        description: 'new description',
      };
      const expectedParams = {
        id: upstreamId,
        data: expectedData,
      };
      const expectResponse = {
        id: upstreamId,
        name: expectedData.name,
        description: expectedData.description,
      };
      mock.onPatch(expectedUrl).reply(HTTP_STATUS_OK, expectResponse);

      return VirtualRegistryApi.updateMavenUpstream(expectedParams).then(({ data }) => {
        expect(data).toEqual(expectResponse);
      });
    });
  });

  describe('updateMavenRegistryUpstreamPosition', () => {
    it('updates the maven upstream registry position', () => {
      const requestPath = 'virtual_registries/packages/maven/registry_upstreams';
      const registryUpstreamId = 1;
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/${requestPath}/${registryUpstreamId}`;
      const expectedParams = {
        id: registryUpstreamId,
        position: 2,
      };
      mock.onPatch(expectedUrl).reply(HTTP_STATUS_OK, 200);

      return VirtualRegistryApi.updateMavenRegistryUpstreamPosition(expectedParams).then(
        ({ data }) => {
          expect(data).toEqual(200);
        },
      );
    });
  });

  describe('removeMavenUpstreamRegistryAssociation', () => {
    it('Removes the association between an upstream registry and a Maven virtual registry', () => {
      const requestPath = 'virtual_registries/packages/maven/registry_upstreams';
      const registryUpstreamId = 1;
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/${requestPath}/${registryUpstreamId}`;
      const expectedParams = {
        id: registryUpstreamId,
      };
      mock.onDelete(expectedUrl).reply(HTTP_STATUS_OK, 200);

      return VirtualRegistryApi.removeMavenUpstreamRegistryAssociation(expectedParams).then(
        ({ data }) => {
          expect(data).toEqual(200);
        },
      );
    });
  });

  describe('deleteMavenUpstream', () => {
    it('deletes the maven upstream', () => {
      const requestPath = 'virtual_registries/packages/maven/upstreams';
      const upstreamId = 1;
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/${requestPath}/${upstreamId}`;
      const expectedParams = {
        id: upstreamId,
      };
      const expectedResponse = {};
      mock.onDelete(expectedUrl).reply(HTTP_STATUS_OK, expectedResponse);

      return VirtualRegistryApi.deleteMavenUpstream(expectedParams).then(({ data }) => {
        expect(data).toEqual(expectedResponse);
      });
    });
  });

  describe('deleteMavenRegistryCache', () => {
    it('deletes upstream cache entry', async () => {
      const requestPath = 'virtual_registries/packages/maven/registries';
      const registryId = '5';
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/${requestPath}/${registryId}/cache`;
      const expectedParams = {
        id: registryId,
      };

      mock.onDelete(expectedUrl).reply(HTTP_STATUS_OK, []);

      const { data } = await VirtualRegistryApi.deleteMavenRegistryCache(expectedParams);

      expect(data).toEqual([]);
      expect(axios.delete).toHaveBeenCalledWith(expectedUrl);
    });
  });

  describe('deleteMavenUpstreamCache', () => {
    it('deletes upstream cache entry', async () => {
      const requestPath = 'virtual_registries/packages/maven/upstreams';
      const upstreamId = '5';
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/${requestPath}/${upstreamId}/cache`;
      const expectedParams = {
        id: upstreamId,
      };

      mock.onDelete(expectedUrl).reply(HTTP_STATUS_OK, []);

      const { data } = await VirtualRegistryApi.deleteMavenUpstreamCache(expectedParams);

      expect(data).toEqual([]);
      expect(axios.delete).toHaveBeenCalledWith(expectedUrl);
    });
  });

  describe('deleteMavenUpstreamCacheEntry', () => {
    it('deletes upstream cache entry', async () => {
      const requestPath = 'virtual_registries/packages/maven/cache_entries';
      const upstreamId = '5';
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/${requestPath}/${upstreamId}`;
      const expectedParams = {
        id: upstreamId,
      };

      mock.onDelete(expectedUrl).reply(HTTP_STATUS_OK, []);

      const { data } = await VirtualRegistryApi.deleteMavenUpstreamCacheEntry(expectedParams);

      expect(data).toEqual([]);
      expect(axios.delete).toHaveBeenCalledWith(expectedUrl);
    });
  });

  describe('testMavenUpstream', () => {
    it('calls test endpoint with parameters', () => {
      const requestPath = 'virtual_registries/packages/maven/upstreams/test';
      const groupPath = 'full-path';
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/groups/${groupPath}/-/${requestPath}`;

      const expectedParams = {
        id: groupPath,
        url: 'https://gitlab.com',
        username: 'test-user',
        password: 'test-password',
      };
      const expectedResponse = {
        success: true,
      };
      mock.onPost(expectedUrl).reply(HTTP_STATUS_OK, expectedResponse);

      return VirtualRegistryApi.testMavenUpstream(expectedParams).then(({ data }) => {
        expect(data).toEqual(expectedResponse);
      });
    });
  });

  describe('testExistingMavenUpstreamWithOverrides', () => {
    const requestPath = 'virtual_registries/packages/maven/upstreams';
    const upstreamId = '5';
    const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/${requestPath}/${upstreamId}/test`;
    const expectedResponse = {
      success: true,
    };

    it('calls test endpoint without body when no overrides are provided', () => {
      const params = {
        id: upstreamId,
      };

      mock.onPost(expectedUrl).reply(HTTP_STATUS_OK, expectedResponse);

      return VirtualRegistryApi.testExistingMavenUpstreamWithOverrides(params).then(({ data }) => {
        expect(data).toEqual(expectedResponse);
        expect(axios.post).toHaveBeenCalledWith(expectedUrl);
      });
    });

    it('calls test endpoint with url, username and password in body', () => {
      const params = {
        id: upstreamId,
        url: 'https://gitlab.com',
        username: 'test-user',
        password: 'test-password',
      };

      const expectedBody = {
        url: params.url,
        username: params.username,
        password: params.password,
      };
      mock.onPost(expectedUrl).reply(HTTP_STATUS_OK, expectedResponse);

      return VirtualRegistryApi.testExistingMavenUpstreamWithOverrides(params).then(({ data }) => {
        expect(data).toEqual(expectedResponse);
        expect(axios.post).toHaveBeenCalledWith(expectedUrl, expectedBody);
      });
    });

    it('calls test endpoint with url and empty username and password as body', () => {
      const params = {
        id: upstreamId,
        url: 'https://gitlab.com',
        username: '',
        password: '',
      };
      const expectedBody = {
        url: params.url,
        username: params.username,
        password: params.password,
      };
      mock.onPost(expectedUrl).reply(HTTP_STATUS_OK, expectedResponse);

      return VirtualRegistryApi.testExistingMavenUpstreamWithOverrides(params).then(({ data }) => {
        expect(data).toEqual(expectedResponse);
        expect(axios.post).toHaveBeenCalledWith(expectedUrl, expectedBody);
      });
    });
  });
});
