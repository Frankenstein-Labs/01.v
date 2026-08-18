import VueApollo from 'vue-apollo';
import Vue from 'vue';
import { GlForm, GlFormGroup } from '@gitlab/ui';
import createContainerProtectionTagRuleMutationPayload from 'test_fixtures/graphql/packages_and_registries/settings/project/graphql/mutations/create_container_protection_tag_rule.mutation.graphql.json';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import ContainerProtectionTagRuleForm from 'ee/packages_and_registries/settings/project/components/container_protection_tag_rule_form.vue';
import createContainerProtectionTagRuleMutation from '~/packages_and_registries/settings/project/graphql/mutations/create_container_protection_tag_rule.mutation.graphql';

Vue.use(VueApollo);

describe('Container Protection Rule Form', () => {
  let wrapper;
  let fakeApollo;

  const defaultProvidedValues = {
    projectPath: 'path',
    glAbilities: {
      createContainerRegistryProtectionImmutableTagRule: true,
    },
  };

  const findForm = () => wrapper.findComponent(GlForm);
  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findProtectionTypeProtectedRadio = () =>
    wrapper.findByRole('radio', { name: /protected/i });
  const findProtectionTypeImmutableRadio = () =>
    wrapper.findByRole('radio', { name: /immutable/i });
  const findTagNamePatternInput = () =>
    wrapper.findByRole('textbox', { name: /protect container tags matching/i });

  const createMutationResolver = jest
    .fn()
    .mockResolvedValue(createContainerProtectionTagRuleMutationPayload);

  const defaultHandlers = [[createContainerProtectionTagRuleMutation, createMutationResolver]];

  const createComponent = ({ provide = defaultProvidedValues, props } = {}) => {
    fakeApollo = createMockApollo(defaultHandlers);

    wrapper = mountExtended(ContainerProtectionTagRuleForm, {
      propsData: props,
      provide,

      apolloProvider: fakeApollo,
    });
  };

  describe('form', () => {
    beforeEach(() => {
      createComponent();
    });

    describe('protection type', () => {
      it('displays form group', () => {
        expect(findFormGroup().exists()).toBe(true);
      });

      it('protected radio exists and is checked by default', () => {
        expect(findProtectionTypeProtectedRadio().element.value).toBe('protected');
        expect(findProtectionTypeProtectedRadio().element.checked).toBe(true);
      });

      it('immutable radio exists and has default value of false', () => {
        expect(findProtectionTypeImmutableRadio().element.value).toBe('immutable');
        expect(findProtectionTypeImmutableRadio().element.checked).toBe(false);
      });
    });
  });

  describe('events', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits submit event to CE component', async () => {
      findTagNamePatternInput().setValue('precious');

      findForm().trigger('submit');

      await waitForPromises();

      expect(wrapper.emitted('submit')).toBeDefined();
    });

    it('emits cancel event to CE component', async () => {
      await findForm().trigger('reset');

      expect(wrapper.emitted('cancel')).toEqual([[]]);
    });
  });

  describe('when user does not have ability to create immutable tag rule', () => {
    beforeEach(() => {
      createComponent({
        provide: {
          ...defaultProvidedValues,
          glAbilities: {
            createContainerRegistryProtectionImmutableTagRule: false,
          },
        },
      });
    });

    it('form field "protectionType" does not exist', () => {
      expect(findProtectionTypeProtectedRadio().exists()).toBe(false);
      expect(findProtectionTypeImmutableRadio().exists()).toBe(false);
    });
  });
});
