import MockAdapter from 'axios-mock-adapter';
import { setHTMLFixture, resetHTMLFixture } from 'helpers/fixtures';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_OK, HTTP_STATUS_UNPROCESSABLE_ENTITY } from '~/lib/utils/http_status';
import { initTestModelConfiguration } from 'ee/pages/admin/application_settings/semantic_search_embeddings/test_model_configuration';

jest.mock('~/alert');

const TEST_PATH =
  '/admin/application_settings/semantic_search_embeddings/code/test_model_configuration';

const TESTED_MODEL_METADATA = {
  model_type: 'gitlab_managed',
  model_ref: 'text_embedding_005_vertex',
  dimensions: 32,
};

const createFixture = () => `
  <form>
    <input type="hidden" name="embedding_model" value="gitlab_managed__text_embedding_005_vertex" />
    <input type="hidden" name="embedding_dimensions" value="32" />
    <input
      type="hidden"
      id="semantic-search-embeddings-tested-model"
      name="tested_model_metadata"
      value=""
    />
    <button
      id="test-model-configuration-button"
      formaction="${TEST_PATH}"
      type="button"
    >Test model configuration</button>
  </form>
`;

const findButton = () => document.getElementById('test-model-configuration-button');
const findTestedModelField = () =>
  document.getElementById('semantic-search-embeddings-tested-model');

describe('initTestModelConfiguration', () => {
  let mockAxios;

  beforeEach(() => {
    setHTMLFixture(createFixture());
    mockAxios = new MockAdapter(axios);
    initTestModelConfiguration();
  });

  afterEach(() => {
    resetHTMLFixture();
    mockAxios.restore();
  });

  const clickButton = () => findButton().click();

  it('disables the button and shows a testing alert on click', async () => {
    mockAxios.onPost(TEST_PATH).replyOnce(HTTP_STATUS_OK, { success: true });

    clickButton();

    expect(findButton().disabled).toBe(true);
    expect(findButton().innerText).toBe('Testing...');
    expect(createAlert).toHaveBeenCalledWith(expect.objectContaining({ variant: 'info' }));

    await waitForPromises();
  });

  describe('on a successful test', () => {
    beforeEach(async () => {
      mockAxios
        .onPost(TEST_PATH)
        .replyOnce(HTTP_STATUS_OK, { success: true, tested_model_metadata: TESTED_MODEL_METADATA });
      clickButton();
      await waitForPromises();
    });

    it('stores the tested model metadata in the hidden field', () => {
      expect(findTestedModelField().value).toBe(JSON.stringify(TESTED_MODEL_METADATA));
    });

    it('shows a success alert', () => {
      expect(createAlert).toHaveBeenCalledWith(expect.objectContaining({ variant: 'success' }));
    });

    it('re-enables the button', () => {
      expect(findButton().disabled).toBe(false);
    });
  });

  describe('on a failed test', () => {
    beforeEach(async () => {
      mockAxios.onPost(TEST_PATH).replyOnce(HTTP_STATUS_UNPROCESSABLE_ENTITY, {
        success: false,
        message: 'Invalid dimensions',
      });
      clickButton();
      await waitForPromises();
    });

    it('shows an error alert with the failure message', () => {
      expect(createAlert).toHaveBeenCalledWith(
        expect.objectContaining({
          message: expect.stringMatching(/Test failed.*Invalid dimensions/),
        }),
      );
    });

    it('re-enables the button', () => {
      expect(findButton().disabled).toBe(false);
    });
  });

  describe('on a non-JSON response (e.g. user has been signed out)', () => {
    beforeEach(async () => {
      mockAxios.onPost(TEST_PATH).replyOnce(HTTP_STATUS_OK, '<html>Login page</html>');
      clickButton();
      await waitForPromises();
    });

    it('shows an unexpected server response alert', () => {
      expect(createAlert).toHaveBeenCalledWith(
        expect.objectContaining({
          message: expect.stringContaining('Unexpected server response'),
        }),
      );
    });

    it('re-enables the button', () => {
      expect(findButton().disabled).toBe(false);
    });
  });

  describe('on a network error', () => {
    beforeEach(async () => {
      mockAxios.onPost(TEST_PATH).networkError();
      clickButton();
      await waitForPromises();
    });

    it('shows an error alert', () => {
      expect(createAlert).toHaveBeenCalledWith(
        expect.objectContaining({ message: expect.any(String) }),
      );
    });

    it('re-enables the button', () => {
      expect(findButton().disabled).toBe(false);
    });
  });
});
