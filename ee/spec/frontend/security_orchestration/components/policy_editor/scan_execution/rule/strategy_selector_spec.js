import { GlCard, GlFormRadio, GlFormRadioGroup } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import StrategySelector from 'ee/security_orchestration/components/policy_editor/scan_execution/rule/strategy_selector.vue';
import {
  STRATEGIES,
  STRATEGIES_RULE_MAP,
} from 'ee/security_orchestration/components/policy_editor/scan_execution/lib';

describe('StrategySelector', () => {
  let wrapper;

  const createComponent = (strategy = 'default') => {
    wrapper = shallowMountExtended(StrategySelector, {
      propsData: {
        strategy,
      },
    });
  };

  const findRadioGroup = () => wrapper.findComponent(GlFormRadioGroup);
  const findCards = () => wrapper.findAllComponents(GlCard);
  const findRadioButtons = () => wrapper.findAllComponents(GlFormRadio);

  describe('rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders a radio group with the correct checked value', () => {
      const strategy = 'custom-strategy';
      createComponent(strategy);

      expect(findRadioGroup().attributes('checked')).toBe(strategy);
    });

    it('displays strategy information correctly', () => {
      STRATEGIES.forEach((strategy, index) => {
        const card = findCards().at(index);
        const radio = findRadioButtons().at(index);

        expect(card.attributes('data-testid')).toBe(strategy.key);
        expect(radio.attributes('value')).toBe(strategy.key);
        expect(card.text()).toContain(strategy.header);
      });
    });
  });

  describe('user interactions', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits changed event with strategy and cloned rules when strategy is selected', () => {
      const selectedStrategy = STRATEGIES[0].key;
      findRadioGroup().vm.$emit('change', selectedStrategy);
      expect(wrapper.emitted('changed')).toHaveLength(1);
      expect(wrapper.emitted('changed')[0][0]).toEqual(
        expect.objectContaining({ strategy: selectedStrategy, rules: expect.any(Array) }),
      );
    });

    it('ensures rules are deep cloned to prevent mutation', () => {
      const selectedStrategy = STRATEGIES[0].key;
      STRATEGIES_RULE_MAP[selectedStrategy] = { nested: { property: 'original' } };

      createComponent();

      const listener = ({ rules }) => {
        // eslint-disable-next-line no-param-reassign
        rules.newNested = { property: 'newProperty' };
        expect(STRATEGIES_RULE_MAP[selectedStrategy]).toStrictEqual({
          nested: { property: 'original' },
        });
      };
      wrapper.vm.$on('changed', listener);

      findRadioGroup().vm.$emit('change', selectedStrategy);
    });
  });
});
