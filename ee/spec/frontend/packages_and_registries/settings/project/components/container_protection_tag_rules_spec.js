import Vue from 'vue';
import VueApollo from 'vue-apollo';
import containerProtectionImmutableTagRuleQueryPayload from 'test_fixtures/graphql/packages_and_registries/settings/project/graphql/queries/get_container_protection_tag_rules.query.graphql.immutable_rules.json';
import createMockApollo from 'helpers/mock_apollo_helper';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import ContainerProtectionTagRules from 'ee/packages_and_registries/settings/project/components/container_protection_tag_rules.vue';
import getContainerProtectionTagRulesQuery from '~/packages_and_registries/settings/project/graphql/queries/get_container_protection_tag_rules.query.graphql';

Vue.use(VueApollo);

describe('ContainerProtectionTagRules', () => {
  let apolloProvider;
  let wrapper;

  const findCrudDescription = () => wrapper.findByTestId('crud-description');
  const findProtectionTypeBadge = () => wrapper.findByTestId('protection-type-badge');

  const defaultProvidedValues = {
    projectPath: 'path',
  };

  const defaultResolver = jest
    .fn()
    .mockResolvedValue(containerProtectionImmutableTagRuleQueryPayload);

  const defaultHandlers = [[getContainerProtectionTagRulesQuery, defaultResolver]];

  const createComponent = (provide = {}) => {
    apolloProvider = createMockApollo(defaultHandlers);
    wrapper = mountExtended(ContainerProtectionTagRules, {
      apolloProvider,
      provide: {
        ...defaultProvidedValues,
        ...provide,
      },
    });
  };

  describe('default', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders correct description', () => {
      expect(findCrudDescription().text()).toBe(
        'Set up rules to protect container image tags from unauthorized changes or make them permanently immutable. Protection rules are checked first, followed by immutable rules. You can add up to 5 protection rules per project.',
      );
    });

    it('displays protection type badge', async () => {
      createComponent({
        containerProtectionTagRuleQueryResolver: jest
          .fn()
          .mockResolvedValue(containerProtectionImmutableTagRuleQueryPayload),
      });

      await waitForPromises();

      expect(findProtectionTypeBadge().text()).toBe('immutable');
    });
  });
});
