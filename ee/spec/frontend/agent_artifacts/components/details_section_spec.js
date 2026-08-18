import { GlAttributeList } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DetailsSection from 'ee/agent_artifacts/components/details_section.vue';
import CollapsibleText from 'ee/agent_artifacts/components/collapsible_text.vue';

describe('DetailsSection', () => {
  let wrapper;

  const createComponent = (details = {}) => {
    wrapper = shallowMountExtended(DetailsSection, {
      propsData: {
        details,
      },
    });
  };

  const findAttributeList = () => wrapper.findComponent(GlAttributeList);
  const findFields = () => (findAttributeList().exists() ? findAttributeList().props('items') : []);
  const fieldLabels = () => findFields().map((item) => item.label);
  const fieldValue = (label) => findFields().find((item) => item.label === label)?.text;
  const findBlock = (key) => wrapper.findByTestId(`details-block-${key}`);
  const findEmpty = () => wrapper.findByTestId('details-empty');
  const findCollapsibleTexts = () => wrapper.findAllComponents(CollapsibleText);

  describe('with generic (non-large-text) keys', () => {
    beforeEach(() => {
      createComponent({
        status: 'finished',
        total_input_tokens: 1800,
        prompt_content: 'the prompt content',
      });
    });

    it('renders each label inline with its value', () => {
      expect(findAttributeList().props('layout')).toBe('horizontal');
    });

    it('renders a key/value row for each non-large-text key', () => {
      expect(fieldLabels()).toEqual(['Status', 'Total input tokens']);
    });

    it('humanizes the key as the label and renders the value', () => {
      expect(fieldValue('Total input tokens')).toBe('1800');
      expect(fieldValue('Status')).toBe('finished');
    });

    it('still renders large-text keys as collapsible blocks, not generic rows', () => {
      expect(fieldLabels()).not.toContain('Prompt content');
      expect(findBlock('prompt_content').exists()).toBe(true);
    });
  });

  describe('with an object-valued key', () => {
    beforeEach(() => {
      createComponent({
        tool_input: { path: 'app/models/user.rb' },
        tool_args: { path: 'app/models/user.rb', line: 42 },
      });
    });

    it('serialises the object value', () => {
      expect(fieldValue('Tool input')).toContain('app/models/user.rb');
      expect(findBlock('tool_args').findComponent(CollapsibleText).props('text')).toContain(
        'app/models/user.rb',
      );
    });
  });

  describe('with blank values', () => {
    beforeEach(() => {
      createComponent({
        status: 'finished',
        empty_string: '',
        whitespace_only: '   ',
        null_value: null,
        undefined_value: undefined,
      });
    });

    it('omits the row entirely rather than rendering a label with no value', () => {
      expect(fieldLabels()).toEqual(['Status']);
    });
  });

  describe('with falsy but meaningful values', () => {
    beforeEach(() => {
      createComponent({ retry_count: 0, cached: false });
    });

    it('keeps rows for zero and false', () => {
      expect(fieldValue('Retry count')).toBe('0');
      expect(fieldValue('Cached')).toBe('false');
    });
  });

  describe('when details is empty', () => {
    beforeEach(() => {
      createComponent({});
    });

    it('renders the empty state and no blocks or fields', () => {
      expect(findEmpty().exists()).toBe(true);
      expect(findAttributeList().exists()).toBe(false);
      expect(findCollapsibleTexts()).toHaveLength(0);
    });
  });

  describe('when keys are present but empty/null', () => {
    beforeEach(() => {
      createComponent({ prompt_content: '', response_content: null, goal: '   ' });
    });

    it('does not render blocks for empty values', () => {
      expect(findBlock('prompt_content').exists()).toBe(false);
      expect(findBlock('response_content').exists()).toBe(false);
      expect(findBlock('goal').exists()).toBe(false);
      expect(findCollapsibleTexts()).toHaveLength(0);
    });
  });

  describe('large-text keys', () => {
    it.each([
      ['goal', 'the goal text'],
      ['prompt_content', 'the prompt content'],
      ['response_content', 'the response content'],
      ['content', 'the content'],
      ['error_message', 'the error message'],
      ['previous_error', 'the previous error'],
    ])('renders %s as a collapsible block', (key, value) => {
      createComponent({ [key]: value });

      expect(findBlock(key).exists()).toBe(true);
      expect(findAttributeList().exists()).toBe(false);
      expect(findBlock(key).findComponent(CollapsibleText).props('text')).toBe(value);
    });
  });
});
