import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import BaseToken from '~/vue_shared/components/filtered_search_bar/tokens/base_token.vue';
import ControlToken from 'ee/compliance_dashboard/components/violations_report/components/tokens/control_token.vue';
import complianceFrameworksWithControlsQuery from 'ee/compliance_dashboard/components/violations_report/graphql/queries/compliance_frameworks_with_controls.query.graphql';
import complianceRequirementControlsQuery from 'ee/compliance_dashboard/graphql/compliance_requirement_controls.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

Vue.use(VueApollo);

describe('ControlToken component', () => {
  let wrapper;
  let mockApollo;

  const groupPath = 'test-group';
  const config = {
    type: 'controlId',
    title: 'Control',
    groupPath,
  };

  const value = {
    data: 'gid://gitlab/ComplianceControl/1',
  };

  const mockFrameworksResponse = {
    data: {
      namespace: {
        id: 'gid://gitlab/Group/1',
        name: 'Test Group',
        complianceFrameworks: {
          nodes: [
            {
              id: 'gid://gitlab/ComplianceFramework/1',
              name: 'SOX Framework',
              color: '#1f75cb',
              description: 'SOX compliance',
              complianceRequirements: {
                nodes: [
                  {
                    id: 'gid://gitlab/ComplianceRequirement/1',
                    name: 'Code Review',
                    complianceRequirementsControls: {
                      nodes: [
                        {
                          id: 'gid://gitlab/ComplianceControl/1',
                          name: 'SAST Running',
                          description: 'SAST must be running',
                        },
                        {
                          id: 'gid://gitlab/ComplianceControl/2',
                          name: 'Minimum Approvals',
                          description: 'At least 2 approvals required',
                        },
                      ],
                    },
                  },
                ],
              },
            },
            {
              id: 'gid://gitlab/ComplianceFramework/2',
              name: 'GDPR Framework',
              color: '#d73a49',
              description: 'GDPR compliance',
              complianceRequirements: {
                nodes: [
                  {
                    id: 'gid://gitlab/ComplianceRequirement/2',
                    name: 'Data Protection',
                    complianceRequirementsControls: {
                      nodes: [
                        {
                          id: 'gid://gitlab/ComplianceControl/3',
                          name: 'Encryption Required',
                          description: 'Data must be encrypted',
                        },
                      ],
                    },
                  },
                ],
              },
            },
          ],
        },
      },
    },
  };

  const mockControlDefinitionsResponse = {
    data: {
      complianceRequirementControls: {
        controlExpressions: [],
      },
    },
  };

  const mockQuerySuccess = jest.fn().mockResolvedValue(mockFrameworksResponse);
  const mockQueryError = jest.fn().mockRejectedValue(new Error('GraphQL error'));

  const findBaseToken = () => wrapper.findComponent(BaseToken);

  const createComponent = (props = {}, queryHandler = mockQuerySuccess) => {
    mockApollo = createMockApollo([
      [complianceFrameworksWithControlsQuery, queryHandler],
      [
        complianceRequirementControlsQuery,
        jest.fn().mockResolvedValue(mockControlDefinitionsResponse),
      ],
    ]);

    wrapper = shallowMount(ControlToken, {
      apolloProvider: mockApollo,
      propsData: {
        config,
        value,
        active: true,
        ...props,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('renders BaseToken with correct props', () => {
    const baseToken = findBaseToken();

    expect(baseToken.exists()).toBe(true);
    expect(baseToken.props('config')).toEqual(config);
    expect(baseToken.props('value')).toEqual(value);
    expect(baseToken.props('active')).toBe(true);
  });

  describe('fetching controls', () => {
    it('fetches controls from frameworks when fetch-suggestions event is emitted', async () => {
      const baseToken = findBaseToken();
      baseToken.vm.$emit('fetch-suggestions');
      await waitForPromises();

      expect(mockQuerySuccess).toHaveBeenCalledWith({
        fullPath: groupPath,
      });
    });

    it('displays control suggestions grouped by framework', async () => {
      const baseToken = findBaseToken();
      baseToken.vm.$emit('fetch-suggestions');
      await waitForPromises();

      const suggestions = baseToken.props('suggestions');
      expect(suggestions).toHaveLength(3);
      expect(suggestions[0]).toMatchObject({
        id: 'gid://gitlab/ComplianceControl/1',
        name: 'SAST Running',
        frameworkName: 'SOX Framework',
        frameworkColor: '#1f75cb',
        requirementName: 'Code Review',
      });
      expect(suggestions[1]).toMatchObject({
        id: 'gid://gitlab/ComplianceControl/2',
        name: 'Minimum Approvals',
        frameworkName: 'SOX Framework',
      });
      expect(suggestions[2]).toMatchObject({
        id: 'gid://gitlab/ComplianceControl/3',
        name: 'Encryption Required',
        frameworkName: 'GDPR Framework',
      });
    });

    it('handles fetch errors', async () => {
      createComponent({}, mockQueryError);

      const baseToken = findBaseToken();
      baseToken.vm.$emit('fetch-suggestions');
      await waitForPromises();

      expect(baseToken.props('suggestionsLoading')).toBe(false);
      expect(baseToken.props('suggestions')).toEqual([]);
    });

    it('handles empty frameworks response', async () => {
      const emptyResponse = {
        data: {
          namespace: {
            id: 'gid://gitlab/Group/1',
            name: 'Test Group',
            complianceFrameworks: {
              nodes: [],
            },
          },
        },
      };
      const mockEmptyQuery = jest.fn().mockResolvedValue(emptyResponse);
      createComponent({}, mockEmptyQuery);

      const baseToken = findBaseToken();
      baseToken.vm.$emit('fetch-suggestions');
      await waitForPromises();

      expect(baseToken.props('suggestions')).toEqual([]);
    });

    it('handles null namespace response', async () => {
      const nullResponse = {
        data: {
          namespace: null,
        },
      };
      const mockNullQuery = jest.fn().mockResolvedValue(nullResponse);
      createComponent({}, mockNullQuery);

      const baseToken = findBaseToken();
      baseToken.vm.$emit('fetch-suggestions');
      await waitForPromises();

      expect(baseToken.props('suggestions')).toEqual([]);
    });
  });

  describe('control selection', () => {
    beforeEach(async () => {
      const baseToken = findBaseToken();
      baseToken.vm.$emit('fetch-suggestions');
      await waitForPromises();
    });

    it('passes correct value identifier function to BaseToken', () => {
      const baseToken = findBaseToken();
      const suggestions = baseToken.props('suggestions');
      const valueIdentifier = baseToken.props('valueIdentifier');

      const controlId = valueIdentifier(suggestions[0]);
      expect(controlId).toBe('gid://gitlab/ComplianceControl/1');
    });

    it('passes get-active-token-value function to BaseToken', () => {
      const baseToken = findBaseToken();
      const suggestions = baseToken.props('suggestions');
      const getActiveTokenValue = baseToken.props('getActiveTokenValue');

      const activeControl = getActiveTokenValue(suggestions, 'gid://gitlab/ComplianceControl/2');

      expect(activeControl).toMatchObject({
        id: 'gid://gitlab/ComplianceControl/2',
        name: 'Minimum Approvals',
      });
    });

    it('returns undefined from get-active-token-value when no matching control found', () => {
      const baseToken = findBaseToken();
      const suggestions = baseToken.props('suggestions');
      const getActiveTokenValue = baseToken.props('getActiveTokenValue');

      const activeControl = getActiveTokenValue(suggestions, 'gid://gitlab/ComplianceControl/999');

      expect(activeControl).toBeUndefined();
    });

    it('returns undefined from get-active-token-value when data is null', () => {
      const baseToken = findBaseToken();
      const suggestions = baseToken.props('suggestions');
      const getActiveTokenValue = baseToken.props('getActiveTokenValue');

      const activeControl = getActiveTokenValue(suggestions, null);

      expect(activeControl).toBeUndefined();
    });
  });

  describe('suggestions rendering', () => {
    it('passes suggestions to BaseToken', async () => {
      const baseToken = findBaseToken();
      baseToken.vm.$emit('fetch-suggestions');
      await waitForPromises();

      const suggestions = baseToken.props('suggestions');
      expect(suggestions).toHaveLength(3);
    });

    it('passes loading state to BaseToken initially', () => {
      const baseToken = findBaseToken();
      expect(baseToken.props('suggestionsLoading')).toBe(false);
    });

    it('configures BaseToken with correct search-by prop', () => {
      const baseToken = findBaseToken();
      expect(baseToken.props('searchBy')).toBe('name');
    });
  });
});
