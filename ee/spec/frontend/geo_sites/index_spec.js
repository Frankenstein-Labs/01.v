import MockAdapter from 'axios-mock-adapter';
import { createWrapper } from '@vue/test-utils';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_OK } from '~/lib/utils/http_status';
import waitForPromises from 'helpers/wait_for_promises';
import { setHTMLFixture, resetHTMLFixture } from 'helpers/fixtures';
import { initGeoSites } from 'ee/geo_sites';
import { GEO_SITE_W_DATA_FIXTURE, MOCK_SITES_RES, MOCK_SITE_STATUSES_RES } from './mock_data';

describe('initGeoSites', () => {
  let wrapper;
  let mock;

  const mockAPI = (apiMocks) => {
    mock = new MockAdapter(axios);
    mock.onGet(/api\/(.*)\/geo_sites/).reply(HTTP_STATUS_OK, apiMocks.res);
    mock.onGet(/api\/(.*)\/geo_sites\/status/).reply(HTTP_STATUS_OK, apiMocks.statusRes);
  };

  const createAppWrapper = async (apiMocks) => {
    mockAPI(apiMocks);
    wrapper = createWrapper(initGeoSites());
    await waitForPromises();
  };

  afterEach(() => {
    resetHTMLFixture();
    mock.restore();
  });

  const findImgWithSrc = (src) => {
    // Vue 3 doesn't set the src attribute on images, so we must find the image by the src property.
    const imgWrapper = wrapper.findAll('img').wrappers.find((w) => w.element.src === src);
    // If we didn't find an image, return an empty wrapper.
    return imgWrapper ?? wrapper.find('img-does-not-exist');
  };

  describe('with no geo elements', () => {
    it('does not return Vue component', () => {
      mockAPI({ res: MOCK_SITES_RES, statusRes: MOCK_SITE_STATUSES_RES });
      setHTMLFixture('<div></div>');
      expect(initGeoSites()).toBe(false);
    });
  });

  describe('with #js-geo-sites and valid data', () => {
    beforeEach(() => {
      setHTMLFixture(GEO_SITE_W_DATA_FIXTURE);
    });

    it('renders a link with the correct URL', async () => {
      await createAppWrapper({
        res: MOCK_SITES_RES,
        statusRes: MOCK_SITE_STATUSES_RES,
      });

      expect(wrapper.find('a[href="admin/geo/sites/new"').exists()).toBe(true);
    });

    it('renders the correct empty state SVG', async () => {
      await createAppWrapper({
        res: [],
        statusRes: [],
      });

      expect(findImgWithSrc('geo/sites/empty-state.svg').exists()).toBe(true);
    });
  });
});
