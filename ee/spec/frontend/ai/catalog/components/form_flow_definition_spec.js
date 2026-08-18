import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import FormFlowDefinition from 'ee/ai/catalog/components/form_flow_definition.vue';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';
import SourceEditor from '~/vue_shared/components/source_editor.vue';

describe('FormFlowDefinition', () => {
  let wrapper;

  const defaultProps = {
    value: 'some YAML content',
    readOnly: false,
  };

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(FormFlowDefinition, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findHeader = () => wrapper.findByTestId('flow-definition-header');
  const findClipboardButton = () => wrapper.findComponent(ClipboardButton);
  const findClearButton = () => wrapper.findComponentByTestId('flow-definition-clear-button');
  const findSourceEditor = () => wrapper.findComponent(SourceEditor);

  describe('default', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders header with clipboard and clear button', () => {
      expect(findHeader().text()).toBe('config.yaml');
      expect(findClipboardButton().props('text')).toBe(defaultProps.value);
      expect(findClearButton().exists()).toBe(true);
    });

    it('renders source editor with correct props', () => {
      expect(findSourceEditor().props('value')).toBe(defaultProps.value);
      expect(findSourceEditor().props('fileName')).toBe('*.yaml');
      expect(findSourceEditor().props('editorOptions')).toEqual({
        padding: { top: 4 },
        readOnly: defaultProps.readOnly,
      });
    });

    it('emits input event when value is changed', async () => {
      await findSourceEditor().vm.$emit('input', 'updated YAML content');

      expect(wrapper.emitted('input')).toEqual([['updated YAML content']]);
    });
  });

  describe('when readOnly is true', () => {
    beforeEach(() => {
      createComponent({ props: { readOnly: true } });
    });

    it('does not render clear button', () => {
      expect(findClearButton().exists()).toBe(false);
    });
  });

  describe('clear button', () => {
    let mockEditor;
    let mockModel;

    beforeEach(() => {
      createComponent();

      mockModel = {
        getFullModelRange: jest.fn().mockReturnValue('full-range'),
      };

      mockEditor = {
        getModel: jest.fn().mockReturnValue(mockModel),
        executeEdits: jest.fn(),
        focus: jest.fn(),
      };

      findSourceEditor().vm.getEditor = jest.fn().mockReturnValue(mockEditor);
    });

    it('clears the editor content using executeEdits', async () => {
      await findClearButton().vm.$emit('click');

      expect(mockEditor.getModel).toHaveBeenCalled();
      expect(mockModel.getFullModelRange).toHaveBeenCalled();
      expect(mockEditor.executeEdits).toHaveBeenCalledWith('clear-button', [
        {
          range: 'full-range',
          text: '',
        },
      ]);
    });

    describe('editor focus behavior', () => {
      it('focuses the editor when clicked with mouse (event detail is not 0)', async () => {
        const mouseClickEvent = new MouseEvent('click', { detail: 1 });
        await findClearButton().vm.$emit('click', mouseClickEvent);

        expect(mockEditor.focus).toHaveBeenCalled();
      });

      it('does not focus the editor when activated with keyboard (event detail is 0)', async () => {
        const keyboardEvent = new MouseEvent('click', { detail: 0 });
        await findClearButton().vm.$emit('click', keyboardEvent);

        expect(mockEditor.focus).not.toHaveBeenCalled();
      });

      it('focuses the editor when no event is passed', async () => {
        await findClearButton().vm.$emit('click');

        expect(mockEditor.focus).toHaveBeenCalled();
      });
    });
  });
});
