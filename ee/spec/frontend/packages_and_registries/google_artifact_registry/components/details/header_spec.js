import { GlAlert, GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ArtifactRegistryDetailsHeader from 'ee_component/packages_and_registries/google_artifact_registry/components/details/header.vue';
import TitleArea from '~/vue_shared/components/registry/title_area.vue';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';

describe('Google Artifact Registry details page header', () => {
  let wrapper;

  const findTitleArea = () => wrapper.findComponent(TitleArea);
  const findURI = () => wrapper.findByTestId('uri');
  const findClipboardButton = () => wrapper.findComponent(ClipboardButton);
  const findOpenInGoogleCloudLink = () => wrapper.findComponent(GlButton);
  const findAlert = () => wrapper.findComponent(GlAlert);

  const defaultProps = {
    data: {
      title: 'title',
      uri: 'location.dev/uri',
      artifactRegistryImageUrl: 'https://location.dev/uri',
    },
  };

  const createComponent = ({ propsData = defaultProps } = {}) => {
    wrapper = shallowMountExtended(ArtifactRegistryDetailsHeader, {
      propsData,
      stubs: {
        TitleArea,
      },
    });
  };

  describe('header', () => {
    it('has a title', () => {
      createComponent({ propsData: { data: {}, isLoading: true } });

      expect(findTitleArea().props()).toMatchObject({
        title: null,
        metadataLoading: true,
      });
      expect(findAlert().exists()).toBe(false);
    });

    it('has external link to google cloud', () => {
      createComponent();

      expect(findOpenInGoogleCloudLink().text()).toBe('Open in Google Cloud');
      expect(findOpenInGoogleCloudLink().attributes('href')).toBe(
        defaultProps.data.artifactRegistryImageUrl,
      );
    });

    it('renders the clipboard button', () => {
      createComponent();

      expect(findClipboardButton().props()).toMatchObject({
        size: 'small',
        text: 'location.dev/uri',
        title: 'Copy image path',
      });
    });

    describe('sub header parts', () => {
      it('renders URI', () => {
        createComponent();

        expect(findURI().text()).toBe('location.dev/uri');
      });
    });

    it('renders alert message when `showError=true`', () => {
      createComponent({ propsData: { showError: true } });

      expect(findAlert().text()).toBe('An error occurred while fetching the artifact details.');
      expect(findURI().exists()).toBe(false);
      expect(findOpenInGoogleCloudLink().exists()).toBe(false);
    });
  });
});
