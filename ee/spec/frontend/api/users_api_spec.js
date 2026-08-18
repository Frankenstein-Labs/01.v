import MockAdapter from 'axios-mock-adapter';
import * as UsersApi from 'ee/api/users_api';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_OK } from '~/lib/utils/http_status';

describe('UsersApi', () => {
  let mock;

  beforeEach(() => {
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    mock.restore();
  });

  describe('validatePasswordComplexity', () => {
    const expectedUrl = '/users/password/complexity';

    const params = {
      first_name: '_first_name_',
      last_name: '_last_name_',
      username: '_username_',
      email: '_email_',
      password: '_password_',
    };

    it('sends user parameters', async () => {
      jest.spyOn(axios, 'post');
      mock.onPost(expectedUrl).replyOnce(HTTP_STATUS_OK, []);

      const { data } = await UsersApi.validatePasswordComplexity(params);

      expect(data).toEqual([]);
      expect(axios.post).toHaveBeenCalledWith(expectedUrl, { user: params });
    });
  });
});
