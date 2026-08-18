import { mountExtended } from 'helpers/vue_test_utils_helper';
import App from 'ee/organizations/show/components/app.vue';

describe('OrganizationShowApp EE', () => {
  let wrapper;

  const defaultPropsData = {
    organization: {
      name: 'GitLab',
      path: 'gitlab',
    },
    canReadArtifactRegistry: true,
    canAdminOrganization: true,
  };

  const createComponent = ({ propsData, glFeatures = { artifactRegistryUi: true } } = {}) => {
    wrapper = mountExtended(App, {
      propsData: { ...defaultPropsData, ...propsData },
      provide: { glFeatures },
    });
  };

  const findArtifactRegistryLink = () =>
    wrapper.findByRole('link', { name: 'Go to Artifact Registry' });

  describe('when the artifact registry feature flag is enabled', () => {
    describe('when user can read artifact registry and admin organization', () => {
      beforeEach(() => {
        createComponent();
      });

      it('renders empty state with the artifact registry and settings description', () => {
        expect(wrapper.text()).toContain(
          "GitLab is your organization's home. Manage Artifact Registry and settings from the sidebar. Learn more.",
        );
      });

      it('renders link to artifact registry', () => {
        expect(findArtifactRegistryLink().attributes('href')).toBe('/o/gitlab/-/artifact_registry');
      });
    });

    describe('when user can read artifact registry', () => {
      beforeEach(() => {
        createComponent({
          propsData: {
            canAdminOrganization: false,
          },
        });
      });

      it('renders empty state with the artifact registry description', () => {
        expect(wrapper.text()).toContain(
          "GitLab is your organization's home. Manage Artifact Registry from the sidebar. Learn more.",
        );
      });

      // The setup page returns 404 without the update ability, so a member is not offered
      // the link. The description asserted above still renders: it points at the sidebar,
      // not at this link.
      it('does not render link to artifact registry', () => {
        expect(findArtifactRegistryLink().exists()).toBe(false);
      });
    });

    describe('when user cannot read artifact registry', () => {
      beforeEach(() => {
        createComponent({
          propsData: {
            canReadArtifactRegistry: false,
          },
        });
      });

      it('does not render link to artifact registry', () => {
        expect(findArtifactRegistryLink().exists()).toBe(false);
      });

      it('does not render artifact registry empty state copy', () => {
        expect(wrapper.text()).not.toContain('Artifact Registry');
      });
    });
  });

  describe('when the artifact registry feature flag is disabled and the user can read artifact registry', () => {
    beforeEach(() => {
      createComponent({ glFeatures: { artifactRegistryUi: false } });
    });

    it('does not render link to artifact registry', () => {
      expect(findArtifactRegistryLink().exists()).toBe(false);
    });

    it('does not render artifact registry empty state copy', () => {
      expect(wrapper.text()).not.toContain('Artifact Registry');
    });
  });
});
