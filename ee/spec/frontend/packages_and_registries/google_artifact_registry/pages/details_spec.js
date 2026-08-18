import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import Details from 'ee_component/packages_and_registries/google_artifact_registry/pages/details.vue';
import DetailsHeader from 'ee_component/packages_and_registries/google_artifact_registry/components/details/header.vue';
import ImageDetails from 'ee_component/packages_and_registries/google_artifact_registry/components/details/image.vue';
import getArtifactDetailsQuery from 'ee_component/packages_and_registries/google_artifact_registry/graphql/queries/get_artifact_details.query.graphql';
import { getArtifactDetailsQueryResponse, imageData, imageDetailsFields } from '../mock_data';

Vue.use(VueApollo);

describe('Details', () => {
  let apolloProvider;
  let wrapper;

  const breadCrumbState = {
    updateName: jest.fn(),
  };

  const provide = {
    breadCrumbState,
    fullPath: 'gitlab-org/gitlab',
  };

  const defaultRouteParams = {
    image: 'alpine@sha256:1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
    projectId: 'dev-package-container-96a3ff34',
    location: 'us-east1',
    repository: 'myrepo',
  };

  function createComponent({
    params = defaultRouteParams,
    resolver = jest.fn().mockResolvedValue(getArtifactDetailsQueryResponse),
  } = {}) {
    const requestHandlers = [[getArtifactDetailsQuery, resolver]];
    apolloProvider = createMockApollo(requestHandlers);

    wrapper = shallowMount(Details, {
      apolloProvider,
      provide,
      mocks: {
        $route: {
          params,
        },
      },
    });
  }

  const findDetailsHeader = () => wrapper.findComponent(DetailsHeader);
  const findImageDetails = () => wrapper.findComponent(ImageDetails);

  describe('details header', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders with loading prop', () => {
      expect(findDetailsHeader().props()).toMatchObject({
        data: {},
        isLoading: true,
        showError: false,
      });
    });

    it('renders with data prop', async () => {
      await waitForPromises();

      expect(findDetailsHeader().props()).toMatchObject({
        data: {
          title: 'alpine@1234567890ab',
          uri: 'us-east1-docker.pkg.dev/dev-package-container-96a3ff34/myrepo/alpine@sha256:6a0657acfef760bd9e293361c9b558e98e7d740ed0dffca823d17098a4ffddf5',
        },
        isLoading: false,
        showError: false,
      });
    });

    it('renders the details header with error prop', async () => {
      const resolver = jest.fn().mockRejectedValue(new Error('error'));
      createComponent({ resolver });
      await waitForPromises();

      expect(findDetailsHeader().props()).toMatchObject({
        data: {},
        isLoading: false,
        showError: true,
      });
    });
  });

  it('calls the appropriate function to set the breadcrumbState', async () => {
    createComponent();
    await waitForPromises();

    expect(breadCrumbState.updateName).toHaveBeenCalledWith('alpine@1234567890ab');
  });

  describe('image details', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the list table with loading prop', () => {
      expect(findImageDetails().props()).toMatchObject({
        data: {},
        isLoading: true,
      });
    });

    it('renders the list table with data prop', async () => {
      await waitForPromises();

      expect(findImageDetails().props()).toMatchObject({
        data: { ...imageData, ...imageDetailsFields },
        isLoading: false,
      });
    });

    it('hides the list table when resolve fails error', async () => {
      const resolver = jest.fn().mockRejectedValue(new Error('error'));
      createComponent({ resolver });
      await waitForPromises();

      expect(findImageDetails().exists()).toBe(false);
    });
  });
});
