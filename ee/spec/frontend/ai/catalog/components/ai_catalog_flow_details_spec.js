import { GlLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCatalogFlowDetails from 'ee/ai/catalog/components/ai_catalog_flow_details.vue';
import AiCatalogItemField from 'ee/ai/catalog/components/ai_catalog_item_field.vue';
import AiCatalogItemVisibilityField from 'ee/ai/catalog/components/ai_catalog_item_visibility_field.vue';
import FormFlowDefinition from 'ee/ai/catalog/components/form_flow_definition.vue';
import FormSection from 'ee/ai/catalog/components/form_section.vue';
import TriggerField from 'ee/ai/catalog/components/trigger_field.vue';
import {
  VERSION_LATEST,
  VERSION_PINNED,
  VISIBILITY_LEVEL_RESTRICTED,
} from 'ee/ai/catalog/constants';
import {
  mockFlow,
  mockFlowConfigurationForProject,
  mockServiceAccount,
  mockItemConfigurationForGroup,
} from '../mock_data';

describe('AiCatalogFlowDetails', () => {
  let wrapper;

  const mockFoundationalFlow = {
    ...mockFlow,
    foundational: true,
    verificationLevel: 'GITLAB_MAINTAINED',
    configurationForGroup: mockItemConfigurationForGroup,
  };

  const defaultProps = {
    item: mockFlow,
    versionKey: VERSION_LATEST,
  };

  const createComponent = ({ props = {}, provide } = {}) => {
    wrapper = shallowMountExtended(AiCatalogFlowDetails, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide,
      stubs: {
        AiCatalogItemVisibilityField,
      },
    });
  };

  const findAllSections = () => wrapper.findAllComponents(FormSection);
  const findSection = (index) => findAllSections().at(index);
  const findAllFieldsForSection = (index) =>
    findSection(index).findAllComponents(AiCatalogItemField);
  const findSourceProjectLink = () => wrapper.findComponent(GlLink);
  const findTriggerField = () => wrapper.findComponent(TriggerField);
  const findServiceAccountField = () => wrapper.findComponentByTestId('service-account-field');
  const findConfigurationField = () => wrapper.findComponentByTestId('configuration-field');
  const findManagedByField = () => wrapper.findComponentByTestId('managed-by-field');

  describe('template', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders 2 sections', () => {
      expect(findAllSections()).toHaveLength(2);
      expect(findSection(0).attributes('title')).toBe('Visibility & access');
      expect(findSection(1).attributes('title')).toBe('Configuration');
    });
  });

  describe('renders "Visibility & access" details', () => {
    let accessRightsDetails;
    beforeEach(() => {
      createComponent();
      accessRightsDetails = findAllFieldsForSection(0);
    });

    it('renders "Visibility & access" details', () => {
      expect(accessRightsDetails.at(1).props('title')).toBe('Visibility');
      expect(accessRightsDetails.at(1).text()).toContain('Public');
    });

    it('passes the item visibility to the visibility field component', () => {
      const visibility = VISIBILITY_LEVEL_RESTRICTED;
      createComponent({ props: { item: { ...mockFlow, visibility } } });

      expect(wrapper.findComponent(AiCatalogItemVisibilityField).props('visibility')).toBe(
        visibility,
      );
    });

    it('renders "Managed by" with link', () => {
      const sourceProjectField = accessRightsDetails.at(0);
      const link = findSourceProjectLink();

      expect(sourceProjectField.props('title')).toBe('Managed by');
      expect(link.attributes('href')).toBe(mockFlow.project.webUrl);
      expect(link.text()).toBe(mockFlow.project.nameWithNamespace);
    });
  });

  describe('renders "Configuration" details', () => {
    describe('default', () => {
      beforeEach(() => {
        createComponent();
      });

      it('renders latestVersion flow definition', () => {
        expect(findConfigurationField().props('title')).toBe('YAML configuration');
        expect(findConfigurationField().findComponent(FormFlowDefinition).props('value')).toBe(
          mockFlow.latestVersion.definition,
        );
      });

      it('does not render triggers field', () => {
        const configurationFields = findAllFieldsForSection(1);
        expect(configurationFields).toHaveLength(1);
      });
    });

    describe('when configurationForProject exists', () => {
      beforeEach(() => {
        createComponent({
          props: {
            item: {
              ...mockFlow,
              configurationForProject: {
                ...mockFlowConfigurationForProject,
              },
            },
            versionKey: VERSION_PINNED,
          },
        });
      });

      it('renders the trigger field', () => {
        expect(findTriggerField().exists()).toBe(true);
      });

      it('renders pinnedItemVersion flow definition', () => {
        expect(findConfigurationField().findComponent(FormFlowDefinition).props('value')).toBe(
          mockFlowConfigurationForProject.pinnedItemVersion.definition,
        );
      });
    });

    describe('when configurationForGroup.serviceAccount exists', () => {
      beforeEach(() => {
        createComponent({
          props: {
            item: {
              ...mockFlow,
              configurationForGroup: {
                serviceAccount: mockServiceAccount,
              },
            },
          },
        });
      });

      it('renders 3 sections', () => {
        expect(findAllSections()).toHaveLength(3);
        expect(findSection(0).attributes('title')).toBe('Visibility & access');
        expect(findSection(1).attributes('title')).toBe('Service account');
        expect(findSection(2).attributes('title')).toBe('Configuration');
      });

      it('renders service account field', () => {
        expect(findServiceAccountField().props()).toMatchObject({
          serviceAccount: mockServiceAccount,
          itemType: 'FLOW',
        });
      });

      it('forwards foundationalFlowReference to the service account field', () => {
        createComponent({
          props: {
            item: {
              ...mockFlow,
              foundationalFlowReference: 'code_review/v1',
              configurationForGroup: {
                serviceAccount: mockServiceAccount,
              },
            },
          },
        });

        expect(findServiceAccountField().props('foundationalFlowReference')).toBe('code_review/v1');
      });
    });
  });

  describe('when the item is foundational', () => {
    describe('and has configurationForGroup', () => {
      beforeEach(() => {
        createComponent({
          props: {
            item: mockFoundationalFlow,
          },
        });
      });

      it('renders "Managed by" field', () => {
        expect(findManagedByField().props('title')).toBe('Managed by');
        expect(findManagedByField().text()).toBe('GitLab');
      });

      it('does not render the Configuration field', () => {
        const configurationSections = findAllSections().filter(
          (section) => section.attributes('title') === 'Configuration',
        );

        if (configurationSections.length > 0) {
          configurationSections.forEach((section) => {
            const configurationFields = section
              .findAllComponents(AiCatalogItemField)
              .filter((field) => field.props('title') === 'Configuration');
            expect(configurationFields).toHaveLength(0);
          });
        } else {
          // Foundational flows within the Catalog won't have any configuration information to show
          expect(configurationSections).toHaveLength(0);
        }
      });
    });

    describe('and does not have configurationForGroup', () => {
      beforeEach(() => {
        createComponent({
          props: {
            item: {
              ...mockFoundationalFlow,
              configurationForGroup: null,
            },
          },
        });
      });

      it('renders "Managed by" field', () => {
        expect(findManagedByField().props('title')).toBe('Managed by');
        expect(findManagedByField().text()).toBe('GitLab');
      });
    });

    describe('and has no content in Configuration section', () => {
      beforeEach(() => {
        createComponent({
          props: {
            item: {
              ...mockFoundationalFlow,
              configurationForGroup: null,
              configurationForProject: null,
            },
          },
        });
      });

      it('does not render the Configuration section', () => {
        const configurationSections = findAllSections().filter(
          (section) => section.attributes('title') === 'Configuration',
        );
        expect(configurationSections).toHaveLength(0);
      });
    });

    describe('and is the Code Review foundational flow', () => {
      beforeEach(() => {
        createComponent({
          props: {
            item: {
              ...mockFoundationalFlow,
              foundationalFlowReference: 'code_review/v1',
              configurationForProject: mockFlowConfigurationForProject,
            },
          },
        });
      });

      it('does not render the Configuration section even with a project configuration', () => {
        const configurationSections = findAllSections().filter(
          (section) => section.attributes('title') === 'Configuration',
        );
        expect(configurationSections).toHaveLength(0);
      });
    });
  });
});
