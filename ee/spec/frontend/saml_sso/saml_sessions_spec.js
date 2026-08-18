import MockAdapter from 'axios-mock-adapter';
import { getExpiringSamlSession } from 'ee/saml_sso/saml_sessions';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_OK } from '~/lib/utils/http_status';

describe('#getExpiringSamlSession', () => {
  let mockAxios;

  const samlProviderId = 1;
  const url = '/test.json';

  beforeEach(() => {
    mockAxios = new MockAdapter(axios);
  });

  describe('when there are no SAML sessions for the current user', () => {
    beforeEach(() => {
      mockAxios.onGet(url).reply(HTTP_STATUS_OK, []);
    });

    it('returns undefined', async () => {
      expect(await getExpiringSamlSession({ samlProviderId, url })).toBeUndefined();
    });
  });

  describe('when the SAML session for the current user has already expired', () => {
    beforeEach(() => {
      mockAxios.onGet(url).reply(HTTP_STATUS_OK, [{ provider_id: 1, time_remaining_ms: -300 }]);
    });

    it('returns undefined', async () => {
      expect(await getExpiringSamlSession({ samlProviderId, url })).toBeUndefined();
    });
  });

  describe('when the SAML session for the current user is about to expire', () => {
    beforeEach(() => {
      mockAxios.onGet(url).reply(HTTP_STATUS_OK, [{ provider_id: 1, time_remaining_ms: 300 }]);
    });

    it('returns info of the session', async () => {
      expect(await getExpiringSamlSession({ samlProviderId, url })).toMatchObject({
        providerId: 1,
        timeRemainingMs: 300,
      });
    });
  });
});
