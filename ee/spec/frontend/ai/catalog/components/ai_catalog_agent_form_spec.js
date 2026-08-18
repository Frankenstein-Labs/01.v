import VueApollo from 'vue-apollo';
import Vue, { nextTick } from 'vue';
import { GlForm, GlAlert, GlSprintf, GlLink } from '@gitlab/ui';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import AiCatalogAgentForm from 'ee/ai/catalog/components/ai_catalog_agent_form.vue';
import aiCatalogBuiltInToolsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_built_in_tools.query.graphql';
import aiCatalogMcpToolsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_mcp_tools.query.graphql';
import aiCatalogMcpServersQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_mcp_servers.query.graphql';
import FormProjectDropdown from 'ee/ai/catalog/components/form_project_dropdown.vue';
import FormGroup from 'ee/ai/catalog/components/form_group.vue';
import VisibilityLevelRadioGroup from 'ee/ai/catalog/components//visibility_level_radio_group.vue';
import FormAgentType from 'ee/ai/catalog/components/form_agent_type.vue';
import {
  VISIBILITY_LEVEL_PRIVATE,
  VISIBILITY_LEVEL_RESTRICTED,
  VISIBILITY_LEVEL_PUBLIC,
} from 'ee/ai/catalog/constants';
import {
  mockToolsIds,
  mockAiCatalogBuiltInToolsNodes,
  mockToolsQueryResponse,
  mockMcpToolsQueryResponse,
  mockMcpServersQueryResponse,
} from '../mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

describe('AiCatalogAgentForm', () => {
  let wrapper;
  let mockApollo;

  const findErrorAlert = () => wrapper.findComponent(ErrorsAlert);
  const findForm = () => wrapper.findComponent(GlForm);
  const findProjectDropdown = () => wrapper.findComponent(FormProjectDropdown);
  const findProjectFormGroup = () => wrapper.findComponent({ ref: 'fieldProject' });
  const findVisibilityLevelRadioGroup = () => wrapper.findComponent(VisibilityLevelRadioGroup);
  const findAgentType = () => wrapper.findComponent(FormAgentType);
  const findNameField = () => wrapper.findComponentByTestId('agent-form-input-name');
  const findDescriptionField = () =>
    wrapper.findComponentByTestId('agent-form-textarea-description');
  const findSystemPromptField = () =>
    wrapper.findComponentByTestId('agent-form-textarea-system-prompt');
  const findToolsField = () => wrapper.findComponentByTestId('agent-form-token-selector-tools');
  const findToolsOptions = () =>
    findToolsField()
      .props('dropdownItems')
      .map((t) => t.name);
  const findMcpServersField = () =>
    wrapper.findComponentByTestId('agent-form-token-selector-mcp-servers');
  const findMcpServersOptions = () =>
    findMcpServersField()
      .props('dropdownItems')
      .map((s) => s.name);
  const findSubmitButton = () => wrapper.findComponentByTestId('agent-form-submit-button');
  const findPublicVisibilityAlert = () => wrapper.findComponent(GlAlert);
  const findAlertLink = () => wrapper.findComponent(GlLink);

  const defaultProps = {
    mode: 'create',
    isLoading: false,
    errors: [],
  };
  const routeParams = { id: 1 };
  const initialValues = {
    projectId: 'gid://gitlab/Project/1000000',
    name: 'My AI Agent',
    description: 'A helpful AI assistant',
    systemPrompt: 'You are a helpful assistant',
    public: true,
    tools: [],
    mcpTools: [],
    mcpServers: [],
    itemType: 'AGENT',
    visibility: VISIBILITY_LEVEL_PUBLIC,
  };

  const mockToolsQueryHandler = jest.fn().mockResolvedValue(mockToolsQueryResponse);
  const mockMcpToolsQueryHandler = jest.fn().mockResolvedValue(mockMcpToolsQueryResponse);
  const mockMcpServersQueryHandler = jest.fn().mockResolvedValue(mockMcpServersQueryResponse);

  const createWrapper = ({
    props = {},
    projectId = '1000000',
    isGlobalNamespace = false,
    instanceBetaFeaturesEnabled = true,
    provide = {},
  } = {}) => {
    mockApollo = createMockApollo([
      [aiCatalogBuiltInToolsQuery, mockToolsQueryHandler],
      [aiCatalogMcpToolsQuery, mockMcpToolsQueryHandler],
      [aiCatalogMcpServersQuery, mockMcpServersQueryHandler],
    ]);

    wrapper = shallowMountExtended(AiCatalogAgentForm, {
      apolloProvider: mockApollo,
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        projectId,
        isGlobalNamespace,
        instanceBetaFeaturesEnabled,
        glAbilities: {
          createAiCatalogThirdPartyFlow: true,
          ...provide.glAbilities,
        },
        glFeatures: {
          aiCatalogThirdPartyFlows: true,
          aiCatalogCreateThirdPartyFlows: true,
          ...provide.glFeatures,
        },
        ...provide,
      },
      mocks: {
        $route: {
          params: props.mode === 'create' ? {} : routeParams,
        },
      },
      stubs: {
        FormGroup,
        GlForm,
        GlSprintf,
      },
    });
  };

  describe('Initial Rendering', () => {
    it('renders the form with the correct initial values when props are provided', () => {
      createWrapper({ props: { initialValues }, isGlobalNamespace: true });

      expect(findProjectDropdown().props('value')).toBe(initialValues.projectId);
      expect(findNameField().props('value')).toBe(initialValues.name);
      expect(findDescriptionField().props('value')).toBe(initialValues.description);
      expect(findSystemPromptField().props('value')).toBe(initialValues.systemPrompt);
      expect(findVisibilityLevelRadioGroup().props('value')).toBe(VISIBILITY_LEVEL_PUBLIC);
      expect(findAgentType().props('value')).toBe(initialValues.itemType);
    });

    it('renders the form with default values when no props are provided and form is global', () => {
      createWrapper({ isGlobalNamespace: true });

      expect(findProjectDropdown().props('value')).toBe(null);
      expect(findNameField().props('value')).toBe('');
      expect(findDescriptionField().props('value')).toBe('');
      expect(findSystemPromptField().props('value')).toBe('');
      expect(findVisibilityLevelRadioGroup().props('value')).toBe(VISIBILITY_LEVEL_PRIVATE);
      expect(findAgentType().props('value')).toBe('AGENT');
    });

    it('renders the form with default values and provided project when no props are provided and form is not global', () => {
      createWrapper({ isGlobalNamespace: false });

      expect(findProjectDropdown().exists()).toBe(false);
      expect(findNameField().props('value')).toBe('');
      expect(findDescriptionField().props('value')).toBe('');
      expect(findSystemPromptField().props('value')).toBe('');
      expect(findVisibilityLevelRadioGroup().props('value')).toBe(VISIBILITY_LEVEL_PRIVATE);
      expect(findAgentType().props('value')).toBe('AGENT');
    });

    describe('when in edit mode', () => {
      beforeEach(() => {
        createWrapper({ props: { mode: 'edit' } });
      });

      it('does not render project dropdown', () => {
        expect(findProjectDropdown().exists()).toBe(false);
      });

      it('renders agent type as disabled', () => {
        expect(findAgentType().props('disabled')).toBe(true);
      });

      describe('when createAiCatalogThirdPartyFlow is null and aiCatalogThirdPartyFlows is false', () => {
        beforeEach(() => {
          createWrapper({
            props: { mode: 'edit' },
            provide: {
              glAbilities: { createAiCatalogThirdPartyFlow: null },
              glFeatures: { aiCatalogThirdPartyFlows: false },
            },
          });
        });

        it('does not render the agent type field', () => {
          expect(findAgentType().exists()).toBe(false);
        });
      });

      describe('when createAiCatalogThirdPartyFlow is null and aiCatalogThirdPartyFlows is true', () => {
        beforeEach(() => {
          createWrapper({
            props: { mode: 'edit' },
            provide: {
              glAbilities: { createAiCatalogThirdPartyFlow: null },
              glFeatures: { aiCatalogThirdPartyFlows: true },
            },
          });
        });

        it('renders agent type as disabled', () => {
          expect(findAgentType().props('disabled')).toBe(true);
        });
      });

      describe('when createAiCatalogThirdPartyFlow is false and aiCatalogThirdPartyFlows is true', () => {
        beforeEach(() => {
          createWrapper({
            props: { mode: 'edit' },
            provide: {
              glAbilities: { createAiCatalogThirdPartyFlow: false },
              glFeatures: { aiCatalogThirdPartyFlows: true },
            },
          });
        });

        it('does not render the agent type field', () => {
          expect(findAgentType().exists()).toBe(false);
        });
      });

      describe('when createAiCatalogThirdPartyFlow is true and aiCatalogThirdPartyFlows is false', () => {
        beforeEach(() => {
          createWrapper({
            props: { mode: 'edit' },
            provide: {
              glAbilities: { createAiCatalogThirdPartyFlow: true },
              glFeatures: { aiCatalogThirdPartyFlows: false },
            },
          });
        });

        it('renders agent type as disabled', () => {
          expect(findAgentType().props('disabled')).toBe(true);
        });
      });
    });
  });

  describe('Tools selection', () => {
    describe('when loaded', () => {
      beforeEach(async () => {
        createWrapper();
        await waitForPromises();
      });

      it('renders tools selector and fetches list data', () => {
        expect(findToolsField().props('selectedTokens')).toEqual([]);
        expect(mockToolsQueryHandler).toHaveBeenCalled();
      });

      it('lists all available built-in and MCP tools sorted alphabetically', () => {
        expect(findToolsOptions()).toStrictEqual([
          'CI Linter',
          'Gitlab Blob Search',
          'Run Git Command',
          'Search',
          'Semantic Code Search',
        ]);
      });

      it('filters available tools based on the search query', async () => {
        findToolsField().vm.$emit('text-input', 'git');
        await nextTick();

        expect(findToolsOptions()).toStrictEqual(['Gitlab Blob Search', 'Run Git Command']);
      });

      describe('when initialValues has tools', () => {
        beforeEach(async () => {
          createWrapper({
            props: {
              initialValues: {
                ...initialValues,
                tools: mockToolsIds,
              },
            },
          });
          await waitForPromises();
        });

        it('renders tools selector with sorted pre-selected tools', () => {
          const selectedTools = findToolsField()
            .props('selectedTokens')
            .map((t) => t.name);
          expect(selectedTools).toStrictEqual([
            'CI Linter',
            'Gitlab Blob Search',
            'Run Git Command',
          ]);
        });
      });

      describe('MCP tools', () => {
        it('fetches and displays MCP tools in the tools dropdown', async () => {
          createWrapper();
          await waitForPromises();

          expect(mockMcpToolsQueryHandler).toHaveBeenCalled();
          expect(findToolsOptions()).toContain('Search');
          expect(findToolsOptions()).toContain('Semantic Code Search');
        });

        it('pre-selects MCP tools and includes mcpTools in submission', async () => {
          createWrapper({
            props: {
              initialValues: {
                ...initialValues,
                mcpTools: ['search', 'semantic_code_search'],
              },
            },
          });
          await waitForPromises();

          const selectedTools = findToolsField()
            .props('selectedTokens')
            .map((t) => t.name);
          expect(selectedTools).toContain('Search');

          await findForm().vm.$emit('submit', { preventDefault: jest.fn() });

          expect(wrapper.emitted('submit')[0][0].mcpTools).toEqual([
            'search',
            'semantic_code_search',
          ]);
        });

        it('marks MCP tools as disabled when instanceBetaFeaturesEnabled is false', async () => {
          createWrapper({ instanceBetaFeaturesEnabled: false });
          await waitForPromises();

          const mcpTools = findToolsField()
            .props('dropdownItems')
            .filter((t) => t.source === 'mcp');
          expect(mcpTools.length).toBeGreaterThan(0);
          expect(mcpTools.every((t) => t.disabled)).toBe(true);
        });

        it('preserves disabled MCP tools when input is emitted', async () => {
          createWrapper({ instanceBetaFeaturesEnabled: false });
          await waitForPromises();

          const disabledMcpTool = findToolsField()
            .props('dropdownItems')
            .find((t) => t.source === 'mcp');
          findToolsField().vm.$emit('input', [disabledMcpTool]);
          await nextTick();

          expect(wrapper.vm.formValues.mcpTools).toEqual([disabledMcpTool.mcpName]);
        });

        it('preserves disabled MCP tools when removing an unrelated built-in tool', async () => {
          createWrapper({
            instanceBetaFeaturesEnabled: false,
            props: {
              initialValues: {
                ...initialValues,
                tools: mockToolsIds,
                mcpTools: ['search'],
              },
            },
          });
          await waitForPromises();

          const selectedTokens = findToolsField().props('selectedTokens');
          const disabledMcp = selectedTokens.find((t) => t.source === 'mcp');
          expect(disabledMcp.disabled).toBe(true);

          // Simulate removing a built-in tool while keeping the disabled MCP tool
          const removedToolId = mockToolsIds[0];
          const remainingTokens = selectedTokens.filter((t) => t.id !== removedToolId);
          findToolsField().vm.$emit('input', remainingTokens);
          await nextTick();

          expect(wrapper.vm.formValues.mcpTools).toEqual(['search']);
          expect(wrapper.vm.formValues.tools).not.toContain(removedToolId);
        });

        describe('deduplication, icons, and tint', () => {
          // Built-in 'Semantic Code Search' shares a machine name with the MCP tool of
          // the same title (title is lower-cased and snake-cased), so it exercises the
          // prefer-MCP dedup path.
          const builtInWithMcpDuplicate = {
            data: {
              aiCatalogBuiltInTools: {
                ...mockToolsQueryResponse.data.aiCatalogBuiltInTools,
                nodes: [
                  ...mockAiCatalogBuiltInToolsNodes,
                  {
                    id: 'gid://gitlab/Ai::Catalog::BuiltInTool/99',
                    title: 'Semantic Code Search',
                    description: 'Built-in semantic code search',
                  },
                ],
              },
            },
          };

          const findSemanticTools = () =>
            findToolsField()
              .props('dropdownItems')
              .filter((t) => t.name === 'Semantic Code Search');

          it('keeps both DAP and MCP entries when duoAgenticChatPreferMcpTools is off', async () => {
            mockToolsQueryHandler.mockResolvedValueOnce(builtInWithMcpDuplicate);
            createWrapper();
            await waitForPromises();

            expect(
              findSemanticTools()
                .map((t) => t.source)
                .sort(),
            ).toEqual(['builtin', 'mcp']);
          });

          it('drops the DAP duplicate in favor of MCP when duoAgenticChatPreferMcpTools is on', async () => {
            mockToolsQueryHandler.mockResolvedValueOnce(builtInWithMcpDuplicate);
            createWrapper({
              provide: {
                glFeatures: { duoAgenticChatPreferMcpTools: true },
              },
            });
            await waitForPromises();

            const semantic = findSemanticTools();
            expect(semantic).toHaveLength(1);
            expect(semantic[0].source).toBe('mcp');
          });

          it('keeps a selected DAP tool even when an MCP duplicate exists', async () => {
            mockToolsQueryHandler.mockResolvedValueOnce(builtInWithMcpDuplicate);
            createWrapper({
              provide: {
                glFeatures: { duoAgenticChatPreferMcpTools: true },
              },
              props: {
                initialValues: {
                  ...initialValues,
                  tools: ['gid://gitlab/Ai::Catalog::BuiltInTool/99'],
                },
              },
            });
            await waitForPromises();

            expect(
              findSemanticTools()
                .map((t) => t.source)
                .sort(),
            ).toEqual(['builtin', 'mcp']);
          });

          it('exposes the GitLab MCP icon URL on MCP tools', async () => {
            createWrapper();
            await waitForPromises();

            const mcpTool = findToolsField()
              .props('dropdownItems')
              .find((t) => t.source === 'mcp');
            expect(mcpTool.iconUrl).toBe('/assets/gitlab_logo.png');
          });

          it('tints selected enabled MCP tokens with semantic warning tokens', async () => {
            createWrapper({
              props: { initialValues: { ...initialValues, mcpTools: ['semantic_code_search'] } },
            });
            await waitForPromises();

            const mcpToken = findToolsField()
              .props('selectedTokens')
              .find((t) => t.source === 'mcp');
            expect(mcpToken.style).toMatchObject({
              borderColor: 'var(--gl-feedback-warning-border-color)',
              backgroundColor: 'var(--gl-feedback-warning-background-color)',
            });
          });
        });
      });
    });
  });

  describe('Agent Type Field', () => {
    describe('when createAiCatalogThirdPartyFlow is null and both flags are false', () => {
      beforeEach(() => {
        createWrapper({
          provide: {
            glAbilities: { createAiCatalogThirdPartyFlow: null },
            glFeatures: {
              aiCatalogThirdPartyFlows: false,
              aiCatalogCreateThirdPartyFlows: false,
            },
          },
        });
      });

      it('does not render the agent type field', () => {
        expect(findAgentType().exists()).toBe(false);
      });
    });

    describe('when createAiCatalogThirdPartyFlow is null and only aiCatalogThirdPartyFlows is true', () => {
      beforeEach(() => {
        createWrapper({
          provide: {
            glAbilities: { createAiCatalogThirdPartyFlow: null },
            glFeatures: {
              aiCatalogThirdPartyFlows: true,
              aiCatalogCreateThirdPartyFlows: false,
            },
          },
        });
      });

      it('does not render the agent type field', () => {
        expect(findAgentType().exists()).toBe(false);
      });
    });

    describe('when createAiCatalogThirdPartyFlow is null and only aiCatalogCreateThirdPartyFlows is true', () => {
      beforeEach(() => {
        createWrapper({
          provide: {
            glAbilities: { createAiCatalogThirdPartyFlow: null },
            glFeatures: {
              aiCatalogThirdPartyFlows: false,
              aiCatalogCreateThirdPartyFlows: true,
            },
          },
        });
      });

      it('does not render the agent type field', () => {
        expect(findAgentType().exists()).toBe(false);
      });
    });

    describe('when createAiCatalogThirdPartyFlow is null and both flags are true', () => {
      beforeEach(() => {
        createWrapper({
          provide: {
            glAbilities: { createAiCatalogThirdPartyFlow: null },
            glFeatures: {
              aiCatalogThirdPartyFlows: true,
              aiCatalogCreateThirdPartyFlows: true,
            },
          },
        });
      });

      it('renders the agent type field', () => {
        expect(findAgentType().exists()).toBe(true);
      });
    });

    describe('when createAiCatalogThirdPartyFlow is false and both flags are false', () => {
      beforeEach(() => {
        createWrapper({
          provide: {
            glAbilities: { createAiCatalogThirdPartyFlow: false },
            glFeatures: {
              aiCatalogThirdPartyFlows: false,
              aiCatalogCreateThirdPartyFlows: false,
            },
          },
        });
      });

      it('does not render the agent type field', () => {
        expect(findAgentType().exists()).toBe(false);
      });
    });

    describe('when createAiCatalogThirdPartyFlow is false and both flags are true', () => {
      beforeEach(() => {
        createWrapper({
          provide: {
            glAbilities: { createAiCatalogThirdPartyFlow: false },
            glFeatures: {
              aiCatalogThirdPartyFlows: true,
              aiCatalogCreateThirdPartyFlows: true,
            },
          },
        });
      });

      it('does not render the agent type field', () => {
        expect(findAgentType().exists()).toBe(false);
      });
    });

    describe('when createAiCatalogThirdPartyFlow is true and both flags are false', () => {
      beforeEach(() => {
        createWrapper({
          provide: {
            glAbilities: { createAiCatalogThirdPartyFlow: true },
            glFeatures: {
              aiCatalogThirdPartyFlows: false,
              aiCatalogCreateThirdPartyFlows: false,
            },
          },
        });
      });

      it('renders the agent type field', () => {
        expect(findAgentType().exists()).toBe(true);
      });
    });

    describe('when createAiCatalogThirdPartyFlow is true and both flags are true', () => {
      beforeEach(() => {
        createWrapper({
          provide: {
            glAbilities: { createAiCatalogThirdPartyFlow: true },
            glFeatures: {
              aiCatalogThirdPartyFlows: true,
              aiCatalogCreateThirdPartyFlows: true,
            },
          },
        });
      });

      it('renders the agent type field', () => {
        expect(findAgentType().exists()).toBe(true);
      });
    });
  });

  describe('Loading Prop', () => {
    it('shows button with loading icon when the loading property is true', () => {
      createWrapper({ props: { isLoading: true } });

      expect(findSubmitButton().props('loading')).toBe(true);
    });

    it('does not show the button with loading icon when the loading property is false', () => {
      createWrapper({ props: { isLoading: false } });

      expect(findSubmitButton().props('loading')).toBe(false);
    });
  });

  describe('Form Submission', () => {
    it('emits form values when user clicks submit', async () => {
      createWrapper({ props: { initialValues } });
      await waitForPromises();

      await findForm().vm.$emit('submit', {
        preventDefault: jest.fn(),
      });

      // With the feature flag off, the form emits the `public` boolean and not `visibility`.
      const { visibility: unusedVisibility, ...expectedValues } = initialValues;
      expect(wrapper.emitted('submit')).toEqual([[expectedValues]]);
    });

    it('trims the form values before emitting them', async () => {
      const addRandomSpacesToString = (value) => `  ${value}  `;

      const formValuesWithRandomSpaces = {
        ...initialValues,
        name: addRandomSpacesToString(initialValues.name),
        description: addRandomSpacesToString(initialValues.description),
        systemPrompt: addRandomSpacesToString(initialValues.systemPrompt),
      };

      createWrapper({ props: { initialValues: formValuesWithRandomSpaces } });
      await waitForPromises();

      await findForm().vm.$emit('submit', {
        preventDefault: jest.fn(),
      });

      const { visibility: unusedVisibility, ...expectedValues } = initialValues;
      expect(wrapper.emitted('submit')).toEqual([[expectedValues]]);
    });

    describe('when aiCatalogInternalVisibility is enabled', () => {
      it('emits the visibility level instead of the public flag', async () => {
        createWrapper({
          props: { initialValues },
          provide: { glFeatures: { aiCatalogInternalVisibility: true } },
        });
        await waitForPromises();

        await findForm().vm.$emit('submit', {
          preventDefault: jest.fn(),
        });

        const { public: unusedPublic, ...expectedValuesWithoutPublic } = initialValues;
        expect(wrapper.emitted('submit')).toEqual([
          [{ ...expectedValuesWithoutPublic, visibility: VISIBILITY_LEVEL_PUBLIC }],
        ]);
      });
    });
  });

  describe('with error messages', () => {
    const mockErrorMessage = 'The agent could not be created';

    beforeEach(() => {
      createWrapper({ props: { errors: [mockErrorMessage] }, isGlobalNamespace: true });
    });

    it('passes error alert', () => {
      expect(findErrorAlert().props('errors')).toEqual([mockErrorMessage]);
    });

    it('renders errors with form errors', async () => {
      const formError = 'Project is required';

      await findProjectDropdown().vm.$emit('error', formError);

      expect(findErrorAlert().props('errors')).toEqual([mockErrorMessage, formError]);
    });

    it('emits dismiss-errors event', () => {
      findErrorAlert().vm.$emit('dismiss');

      expect(wrapper.emitted('dismiss-errors')).toHaveLength(1);
    });
  });

  describe('Project field validation', () => {
    beforeEach(() => {
      createWrapper({ isGlobalNamespace: true });
    });

    it('shows validation error when form is submitted and project is not selected', async () => {
      await findForm().vm.$emit('submit', {
        preventDefault: jest.fn(),
      });

      expect(findProjectFormGroup().attributes('state')).toBeUndefined();
    });

    it('clears validation error when project is selected', async () => {
      await findForm().vm.$emit('submit', {
        preventDefault: jest.fn(),
      });

      findProjectDropdown().vm.$emit('input', 'gid://gitlab/Project/123');

      await nextTick(); // formValues.projectId value updates, triggering watcher
      await nextTick(); // formValues.projectId watcher executes
      await nextTick(); // $nextTick callback executes, revalidating project field

      expect(findProjectFormGroup().attributes('state')).toBe('true');
    });
  });

  describe('MCP Servers', () => {
    beforeEach(async () => {
      createWrapper({
        isGlobalNamespace: true,
        provide: {
          glAbilities: {
            readAiCatalogMcpServer: true,
          },
        },
      });
      await waitForPromises();
    });

    it('renders MCP servers field when user has permission', () => {
      expect(findMcpServersField().exists()).toBe(true);
    });

    it('loads available MCP servers', () => {
      expect(findMcpServersOptions()).toEqual(['Test MCP Server 1', 'Test MCP Server 2']);
    });

    it('allows selecting MCP servers', async () => {
      const mcpServers = mockMcpServersQueryResponse.data.aiCatalogMcpServers.nodes.map((s) => ({
        id: s.id,
        name: s.name,
        description: s.description,
      }));

      await findMcpServersField().vm.$emit('input', mcpServers);
      await nextTick();

      expect(findMcpServersField().props('selectedTokens')).toEqual(mcpServers);
    });

    it('includes MCP servers in form submission', async () => {
      const mcpServers = mockMcpServersQueryResponse.data.aiCatalogMcpServers.nodes.map((s) => ({
        id: s.id,
        name: s.name,
        description: s.description,
      }));

      // Set required form fields first
      await findNameField().vm.$emit('input', 'Test Agent');
      await findDescriptionField().vm.$emit('input', 'Test Description');
      await findSystemPromptField().vm.$emit('input', 'Test System Prompt');
      await findProjectDropdown().vm.$emit('input', 'gid://gitlab/Project/1');

      await findMcpServersField().vm.$emit('input', mcpServers);
      await nextTick();
      await findForm().vm.$emit('submit', { preventDefault: jest.fn() });

      const emittedSubmit = wrapper.emitted('submit')[0][0];
      expect(emittedSubmit.mcpServers).toEqual(mcpServers.map((s) => s.id));
    });

    describe('when user does not have permission', () => {
      beforeEach(async () => {
        createWrapper({
          isGlobalNamespace: true,
          provide: {
            glAbilities: {
              readAiCatalogMcpServer: false,
            },
          },
        });
        await waitForPromises();
      });

      it('does not render MCP servers field', () => {
        expect(findMcpServersField().exists()).toBe(false);
      });
    });
  });

  describe('Public visibility alert', () => {
    describe('when visibility level is private', () => {
      beforeEach(async () => {
        createWrapper({
          props: {
            initialValues: {
              ...initialValues,
              public: false,
              visibility: VISIBILITY_LEVEL_PRIVATE,
            },
          },
        });
        await waitForPromises();
      });

      it('does not render alert', () => {
        expect(findPublicVisibilityAlert().exists()).toBe(false);
      });
    });

    describe('when visibility level is restricted', () => {
      beforeEach(async () => {
        createWrapper({
          props: {
            initialValues: {
              ...initialValues,
              public: false,
              visibility: VISIBILITY_LEVEL_RESTRICTED,
            },
          },
        });
        await waitForPromises();
      });

      it('does not render alert', () => {
        expect(findPublicVisibilityAlert().exists()).toBe(false);
      });
    });

    describe('when visibility level is public', () => {
      beforeEach(async () => {
        createWrapper({ props: { initialValues } });
        await waitForPromises();
      });

      it('renders alert', () => {
        expect(findPublicVisibilityAlert().exists()).toBe(true);
      });

      it('renders alert with correct message', () => {
        expect(findPublicVisibilityAlert().text()).toBe(
          "If a public agent is enabled, you can't delete it or make it private. Learn more about agent visibility.",
        );
      });

      it('renders alert with correct link', () => {
        expect(findAlertLink().attributes('href')).toBe(
          '/help/user/duo_agent_platform/agents/custom#agent-visibility',
        );
      });

      it('alert is not dismissible', () => {
        expect(findPublicVisibilityAlert().props('dismissible')).toBe(false);
      });
    });

    describe('when visibility level changes', () => {
      it('shows alert when visibility level changes from private to public', async () => {
        createWrapper({
          props: {
            initialValues: {
              ...initialValues,
              public: false,
              visibility: VISIBILITY_LEVEL_PRIVATE,
            },
          },
        });
        await waitForPromises();

        expect(findPublicVisibilityAlert().exists()).toBe(false);

        findVisibilityLevelRadioGroup().vm.$emit('input', VISIBILITY_LEVEL_PUBLIC);
        await nextTick();

        expect(findPublicVisibilityAlert().exists()).toBe(true);
      });

      it('hides alert when visibility level changes from public to private', async () => {
        createWrapper({ props: { initialValues } });
        await waitForPromises();

        expect(findPublicVisibilityAlert().exists()).toBe(true);

        findVisibilityLevelRadioGroup().vm.$emit('input', VISIBILITY_LEVEL_PRIVATE);
        await nextTick();

        expect(findPublicVisibilityAlert().exists()).toBe(false);
      });
    });
  });

  describe('when Apollo queries fail', () => {
    const error = new Error('GraphQL error');

    it('reports availableTools query error to Sentry', async () => {
      mockToolsQueryHandler.mockRejectedValue(error);
      createWrapper();
      await waitForPromises();

      expect(Sentry.captureException).toHaveBeenCalledWith(error);
    });

    it('reports availableMcpServers query error to Sentry', async () => {
      mockMcpServersQueryHandler.mockRejectedValue(error);
      createWrapper({
        provide: {
          glAbilities: { createAiCatalogThirdPartyFlow: true, readAiCatalogMcpServer: true },
        },
      });
      await waitForPromises();

      expect(Sentry.captureException).toHaveBeenCalledWith(error);
    });
  });
});
