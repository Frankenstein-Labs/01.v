import MockAdapter from 'axios-mock-adapter';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_OK } from '~/lib/utils/http_status';
import { syncPullMirror, deletePullMirror } from 'ee/api/pull_mirror_api';

describe('Pull Mirror API', () => {
  const dummyUrlRoot = '';
  const dummyApiVersion = 'v4';

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

  describe('syncPullMirror', () => {
    it('posts to the pull mirror sync endpoint', async () => {
      const expectedUrl = `/api/${dummyApiVersion}/projects/7/mirror/pull`;
      mock.onPost(expectedUrl).replyOnce(HTTP_STATUS_OK);

      await syncPullMirror(7);

      expect(mock.history.post).toHaveLength(1);
      expect(mock.history.post[0].url).toBe(expectedUrl);
    });
  });

  describe('deletePullMirror', () => {
    it('puts enabled: false to the pull mirror endpoint', async () => {
      const expectedUrl = `/api/${dummyApiVersion}/projects/7/mirror/pull`;
      mock.onPut(expectedUrl).replyOnce(HTTP_STATUS_OK);

      await deletePullMirror(7);

      expect(mock.history.put).toHaveLength(1);
      expect(mock.history.put[0].url).toBe(expectedUrl);
      expect(JSON.parse(mock.history.put[0].data)).toEqual({ enabled: false });
    });
  });
});
