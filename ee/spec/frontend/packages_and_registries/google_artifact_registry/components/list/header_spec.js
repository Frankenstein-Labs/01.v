import { GlAlert } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import ArtifactRegistryListHeader from 'ee_component/packages_and_registries/google_artifact_registry/components/list/header.vue';
import TitleArea from '~/vue_shared/components/registry/title_area.vue';
import { headerData } from '../../mock_data';

describe('Google Artifact Registry list page header', () => {
  let wrapper;

  const findTitleArea = () => wrapper.findComponent(TitleArea);
  const findRepositoryNameSubHeader = () => wrapper.findComponentByTestId('repository-name');
  const findProjectIDSubHeader = () => wrapper.findComponentByTestId('project-id');
  const findOpenInGoogleCloudLink = () => wrapper.findByTestId('external-link');
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findSettingsLink = () => wrapper.findComponentByTestId('settings-link');

  const defaultProvide = { settingsPath: '/settings' };
  const defaultProps = { data: headerData };

  const createComponent = ({ propsData = defaultProps, provide = defaultProvide } = {}) => {
    wrapper = shallowMountExtended(ArtifactRegistryListHeader, {
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      provide,
      propsData,
      stubs: {
        TitleArea,
      },
    });
  };

  describe('header', () => {
    it('renders title while loading', () => {
      createComponent({ propsData: { data: {}, isLoading: true } });

      expect(findTitleArea().props()).toMatchObject({
        title: 'Google Artifact Registry',
        metadataLoading: true,
      });
      expect(findAlert().exists()).toBe(false);
    });

    it('hides external link to google cloud', () => {
      createComponent();

      expect(findOpenInGoogleCloudLink().exists()).toBe(false);
    });

    it('has external link to google cloud', () => {
      createComponent({ propsData: { ...defaultProps, showExternalLink: true } });

      expect(findOpenInGoogleCloudLink().text()).toBe('Open in Google Cloud');
      expect(findOpenInGoogleCloudLink().attributes('href')).toBe(
        defaultProps.data.artifactRegistryRepositoryUrl,
      );
    });

    describe('link to settings', () => {
      describe('when settings path is not provided', () => {
        beforeEach(() => {
          createComponent({
            provide: {
              ...defaultProvide,
              settingsPath: '',
            },
          });
        });

        it('is not rendered', () => {
          expect(findSettingsLink().exists()).toBe(false);
        });
      });

      describe('when settings path is provided', () => {
        const label = 'Configure in settings';

        beforeEach(() => {
          createComponent();
        });

        it('is rendered', () => {
          expect(findSettingsLink().exists()).toBe(true);
        });

        it('has the right icon', () => {
          expect(findSettingsLink().props('icon')).toBe('settings');
        });

        it('has the right attributes', () => {
          expect(findSettingsLink().attributes()).toMatchObject({
            'aria-label': label,
            href: defaultProvide.settingsPath,
          });
        });

        it('sets tooltip with right label', () => {
          const tooltip = getBinding(findSettingsLink().element, 'gl-tooltip');

          expect(tooltip.value).toBe(label);
        });
      });
    });

    describe('sub header parts', () => {
      describe('repository name', () => {
        it('exists', () => {
          createComponent();

          expect(findRepositoryNameSubHeader().props()).toMatchObject({
            icon: 'folder',
            text: `Repository: ${defaultProps.data.repository}`,
            size: 'l',
          });
        });
      });

      describe('project id', () => {
        it('exists', () => {
          createComponent();

          expect(findProjectIDSubHeader().props()).toMatchObject({
            icon: 'project',
            text: `Project ID: ${defaultProps.data.projectId}`,
            size: 'l',
          });
        });
      });
    });

    describe('has error', () => {
      it('shows alert', () => {
        createComponent({ propsData: { showError: true } });

        expect(findAlert().text()).toBe('An error occurred while fetching the artifacts.');
        expect(findRepositoryNameSubHeader().exists()).toBe(false);
        expect(findProjectIDSubHeader().exists()).toBe(false);
        expect(findOpenInGoogleCloudLink().exists()).toBe(false);
      });
    });
  });
});
