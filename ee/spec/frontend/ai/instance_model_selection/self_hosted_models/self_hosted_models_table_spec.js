import Vue from 'vue';
import VueApollo from 'vue-apollo';
import {
  GlTable,
  GlDisclosureDropdown,
  GlLink,
  GlTruncate,
  GlSearchBoxByType,
  GlSkeletonLoader,
} from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import getSelfHostedModelsQuery from 'ee/ai/instance_model_selection/self_hosted_models/graphql/queries/get_self_hosted_models.query.graphql';
import SelfHostedModelsTable from 'ee/ai/instance_model_selection/self_hosted_models/components/self_hosted_models_table.vue';
import DeleteSelfHostedModelDisclosureItem from 'ee/ai/instance_model_selection/self_hosted_models/components/delete_self_hosted_model_disclosure_item.vue';
import { createAlert } from '~/alert';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import waitForPromises from 'helpers/wait_for_promises';
import { mockSelfHostedModelsList } from './mock_data';

Vue.use(VueApollo);

jest.mock('~/alert');

describe('SelfHostedModelsTable', () => {
  let wrapper;

  const getSelfHostedModelsSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      aiSelfHostedModels: {
        nodes: mockSelfHostedModelsList,
        errors: [],
      },
    },
  });

  const createComponent = ({
    apolloHandlers = [[getSelfHostedModelsQuery, getSelfHostedModelsSuccessHandler]],
    provide = {},
  } = {}) => {
    const mockApollo = createMockApollo([...apolloHandlers]);

    wrapper = mountExtended(SelfHostedModelsTable, {
      apolloProvider: mockApollo,
      provide: {
        canManageSelfHostedModels: true,
        ...provide,
      },
    });
  };

  const findTable = () => wrapper.findComponent(GlTable);
  const findLoaders = () => wrapper.findAllComponents(GlSkeletonLoader);
  const findTableHeaders = () => findTable().findAllComponents('th');
  const findTableRows = () => findTable().findAllComponents('tbody > tr');
  const findNthTableRow = (idx) => findTableRows().at(idx);
  const findSearchBox = () => wrapper.findComponent(GlSearchBoxByType);
  const findDisclosureDropdowns = () => wrapper.findAllComponents(GlDisclosureDropdown);
  const findEditButtons = () => wrapper.findAllComponentsByTestId('model-edit-button');
  const findEmptyStateLink = () => wrapper.findComponent(GlLink);
  const findTruncators = () => wrapper.findAllComponents(GlTruncate);
  const findDeleteDisclosureItems = () =>
    wrapper.findAllComponents(DeleteSelfHostedModelDisclosureItem);

  it('renders the table component', () => {
    createComponent();

    expect(findTable().exists()).toBe(true);
  });

  it('renders table headers <th>', () => {
    createComponent();

    const expectedTableHeaderNames = [
      'Name',
      'Model family',
      'Endpoint',
      'Model identifier',
      'API token',
      'Actions', // hidden when in desktop view
    ];

    expect(findTableHeaders().wrappers.map((h) => h.text())).toEqual(expectedTableHeaderNames);
  });

  describe('when model data is loading', () => {
    it('renders skeleton loaders', () => {
      createComponent();

      expect(findLoaders().exists()).toBe(true);
    });
  });

  describe('when the API query is successful', () => {
    beforeEach(async () => {
      createComponent();

      await waitForPromises();
    });

    it('renders self-hosted model entries', () => {
      const modelRow = findNthTableRow(1);

      const modelRowText = modelRow
        .findAll('td')
        .wrappers.map((cell) => cell.text().replace(/\u200E/g, '')); // Remove U+200E left-to-right marks added by the GlTruncate component

      expect(findTableRows()).toHaveLength(3);
      expect(modelRowText).toContain('mock-self-hosted-model-2');
      expect(modelRowText).toContain('Mistral');
      expect(modelRowText).toContain('https://mock-endpoint-2.com');
      expect(modelRowText).toContain('provider/some-model-2');
      expect(modelRow.find('[data-testid="check-circle-icon"]').exists()).toBe(true);
    });

    describe('bedrock model entries', () => {
      it('does not render the dummy endpoint', () => {
        const bedrockModel = findNthTableRow(2);
        const bedrockModelName = bedrockModel.find('[data-label="Name"]').text();
        const bedrockModelEndpoint = bedrockModel.find('[data-label="Endpoint"]').text();

        expect(bedrockModelName).toBe('mock-bedrock-self-hosted-model');
        expect(bedrockModelEndpoint).toBe('--');
      });
    });

    describe('beta model entries', () => {
      it('renders a beta badge in the row', () => {
        const betaModelCell = findNthTableRow(0).findAll('td').at(1);

        expect(betaModelCell.text()).toContain('Code Llama');
        expect(betaModelCell.find('.gl-badge-content').text()).toContain('Beta');
      });
    });

    it('truncates name, endpoint, and model identifier', () => {
      const model = mockSelfHostedModelsList[0];

      const nameTruncator = findTruncators().at(0);
      const endpointTruncator = findTruncators().at(1);
      const modelIdentifierTruncator = findTruncators().at(2);

      expect(nameTruncator.props('text')).toBe(model.name);
      expect(endpointTruncator.props('text')).toBe(model.endpoint);
      expect(modelIdentifierTruncator.props('text')).toBe(model.identifier);
    });

    it('renders a disclosure dropdown for each self-hosted model entry', () => {
      expect(findDisclosureDropdowns()).toHaveLength(3);
    });

    describe('search', () => {
      beforeEach(() => {
        createComponent({ props: { models: mockSelfHostedModelsList } });
      });

      it('renders a search bar', () => {
        expect(findSearchBox().exists()).toBe(true);
      });

      it('can search the table', async () => {
        await findSearchBox().vm.$emit('input', 'mock-self-hosted-model-1');

        expect(findTableRows()).toHaveLength(1);
        expect(findTableRows().at(0).text()).toContain('mock-self-hosted-model-1');
      });
    });

    describe('when there are no self-hosted models', () => {
      const getSelfHostedModelsEmptyHandler = jest.fn().mockResolvedValue({
        data: {
          aiSelfHostedModels: {
            nodes: [],
            errors: [],
          },
        },
      });

      describe('when user can manage self-hosted models', () => {
        beforeEach(async () => {
          createComponent({
            apolloHandlers: [[getSelfHostedModelsQuery, getSelfHostedModelsEmptyHandler]],
            provide: {
              canManageSelfHostedModels: true,
            },
          });

          await waitForPromises();
        });

        it('renders empty state text with link', () => {
          expect(findTable().text()).toMatch(
            'No self-hosted models yet. Add a self-hosted model and select it for a feature to start using it.',
          );
        });

        it('renders a link to create a new self-hosted model', () => {
          expect(findEmptyStateLink().exists()).toBe(true);
          expect(findEmptyStateLink().props('to')).toEqual({ name: 'new' });
        });
      });

      describe('when user cannot manage self-hosted models', () => {
        beforeEach(async () => {
          createComponent({
            apolloHandlers: [[getSelfHostedModelsQuery, getSelfHostedModelsEmptyHandler]],
            provide: {
              canManageSelfHostedModels: false,
            },
          });

          await waitForPromises();
        });

        it('renders empty state text with Enterprise requirement message', () => {
          expect(findTable().text()).toMatch(
            'Self-hosted models are available only with the GitLab Duo Enterprise add-on. Contact your administrator.',
          );
        });

        it('does not render a link to create a new self-hosted model', () => {
          expect(findEmptyStateLink().exists()).toBe(false);
        });
      });
    });

    describe('Editing a model', () => {
      describe('when user can manage self-hosted models', () => {
        beforeEach(async () => {
          createComponent({
            provide: {
              canManageSelfHostedModels: true,
            },
          });

          await waitForPromises();
        });

        it('renders an edit button for each model', () => {
          expect(findEditButtons()).toHaveLength(3);

          findEditButtons().wrappers.forEach((button) => {
            expect(button.text()).toEqual('Edit');
          });
        });

        it('routes to the Edit page when edit button is clicked', () => {
          const modelIdAtIdx0 = getIdFromGraphQLId(mockSelfHostedModelsList[0].id);

          expect(findEditButtons().at(0).props('item')).toEqual({
            text: 'Edit',
            to: { name: 'edit', params: { id: modelIdAtIdx0 } },
          });
        });
      });

      describe('when user cannot manage self-hosted models', () => {
        beforeEach(async () => {
          createComponent({
            provide: {
              canManageSelfHostedModels: false,
            },
          });

          await waitForPromises();
        });

        it('does not render edit buttons', () => {
          expect(findEditButtons()).toHaveLength(0);
        });

        it('does not render action dropdowns', () => {
          expect(findDisclosureDropdowns()).toHaveLength(0);
        });
      });
    });

    describe('Deleting a model', () => {
      describe('when user can manage self-hosted models', () => {
        it('renders a delete button for each model', async () => {
          createComponent({
            provide: {
              canManageSelfHostedModels: true,
            },
          });

          await waitForPromises();

          expect(findDeleteDisclosureItems()).toHaveLength(3);

          findDeleteDisclosureItems().wrappers.forEach((button) => {
            expect(button.text()).toEqual('Delete');
          });
        });
      });

      describe('when user cannot manage self-hosted models', () => {
        it('does not render delete buttons', async () => {
          createComponent({
            provide: {
              canManageSelfHostedModels: false,
            },
          });

          await waitForPromises();

          expect(findDeleteDisclosureItems()).toHaveLength(0);
        });
      });
    });
  });

  describe('when the API request is unsuccessful', () => {
    describe('due to of a general error', () => {
      it('displays an error message', async () => {
        createComponent({
          apolloHandlers: [[getSelfHostedModelsQuery, jest.fn().mockRejectedValue('ERROR')]],
        });

        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith(
          expect.objectContaining({
            message: 'An error occurred while loading self-hosted models. Please try again.',
          }),
        );
      });
    });

    describe('due to a business logic error', () => {
      const getSelfHostedModelsErrorHandler = jest.fn().mockResolvedValue({
        data: {
          aiFeatureSettings: {
            errors: ['An error occured'],
          },
        },
      });

      it('displays an error message', async () => {
        createComponent({
          apolloHandlers: [[getSelfHostedModelsQuery, getSelfHostedModelsErrorHandler]],
        });

        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith(
          expect.objectContaining({
            message: 'An error occurred while loading self-hosted models. Please try again.',
          }),
        );
      });
    });
  });
});
