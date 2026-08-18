import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { GlButton } from '@gitlab/ui';
import AiGenie from 'ee/ai/components/ai_genie.vue';
import Chunk from '~/vue_shared/components/source_viewer/components/chunk.vue';
import { sendDuoChatCommand } from 'ee/ai/utils';
import { i18n, GENIE_CHAT_EXPLAIN_MESSAGE } from 'ee/ai/constants';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { setHTMLFixture, resetHTMLFixture } from 'helpers/fixtures';
import LineHighlighter from '~/blob/line_highlighter';
import { getMarkdown } from '~/rest_api';

const lineHighlighter = new LineHighlighter();
jest.mock('~/blob/line_highlighter', () =>
  jest.fn().mockReturnValue({
    highlightRange: jest.fn(),
    clearHighlight: jest.fn(),
  }),
);
jest.mock('ee/ai/utils', () => ({
  generateExplainCodePrompt: jest.fn(),
  generateChatPrompt: jest.fn(),
  sendDuoChatCommand: jest.fn(),
}));
jest.mock('~/rest_api');
jest.mock('~/alert');
jest.mock('~/code_navigation/utils');

Vue.use(VueApollo);
Vue.use(Vuex);

const SELECTION_START_POSITION = 50;
const SELECTION_END_POSITION = 150;
const OFFSET_PARENT_TOP = 20;
const LINE_ID = 'LC1';

describe('AiGenie', () => {
  let wrapper;
  const containerSelector = '.container';
  const filePath = 'some_file.js';
  const language = 'vue';
  const resourceId = 'gid://gitlab/Project/1';

  const createComponent = ({ propsData = { containerSelector, filePath }, data = {} } = {}) => {
    wrapper = shallowMountExtended(AiGenie, {
      propsData,
      data() {
        return data;
      },
      provide: {
        resourceId,
      },
    });
    // jsdom has no layout, so offsetParent is null; stub it so setPosition succeeds.
    Object.defineProperty(wrapper.element, 'offsetParent', {
      configurable: true,
      value: { getBoundingClientRect: () => ({ top: 0 }) },
    });
  };
  const findButton = () => wrapper.findComponent(GlButton);

  const getRangeAtMock = (top = () => 0) => {
    return jest.fn((rangePosition) => {
      return {
        getBoundingClientRect: jest.fn(() => {
          return {
            top: top(rangePosition),
            left: 0,
            right: 0,
            bottom: 0,
          };
        }),
      };
    });
  };
  const getSelectionMock = ({ getRangeAt = getRangeAtMock(), toString = () => {} } = {}) => {
    return {
      anchorNode: document.getElementById('first-paragraph'),
      focusNode: document.getElementById('first-paragraph'),
      isCollapsed: false,
      getRangeAt,
      rangeCount: 10,
      toString,
      removeAllRanges: jest.fn(),
    };
  };

  const simulateSelectionEvent = () => {
    const selectionChangeEvent = new Event('selectionchange');
    document.dispatchEvent(selectionChangeEvent);
  };

  const waitForDebounce = async () => {
    await nextTick();
    jest.runOnlyPendingTimers();
  };

  const simulateSelectText = async ({
    contains = true,
    getSelection = getSelectionMock(),
  } = {}) => {
    jest.spyOn(window, 'getSelection').mockImplementation(() => getSelection);
    jest
      .spyOn(document.querySelector(containerSelector), 'contains')
      .mockImplementation(() => contains);
    simulateSelectionEvent();
    await waitForDebounce();
  };

  const requestExplanation = async () => {
    await findButton().vm.$emit('click');
  };

  beforeEach(() => {
    setHTMLFixture(
      `<div class="container" style="height:1000px; width: 800px"><span class="line" id="${LINE_ID}"><p lang=${language} id="first-paragraph">Foo</p></span></div>`,
    );
    getMarkdown.mockImplementation(({ text }) => Promise.resolve({ data: { html: text } }));
  });

  afterEach(() => {
    resetHTMLFixture();
  });

  it('correctly renders the component by default', () => {
    createComponent();
    expect(findButton().exists()).toBe(true);
  });

  describe('the toggle button', () => {
    beforeEach(() => {
      createComponent();
    });

    it('is hidden by default, yet gets the correct props', () => {
      const btnWrapper = findButton();
      expect(btnWrapper.isVisible()).toBe(false);
      expect(btnWrapper.attributes('title')).toBe(i18n.GENIE_TOOLTIP);
    });

    it('is rendered when a text is selected', async () => {
      await simulateSelectText();
      expect(findButton().isVisible()).toBe(true);
    });

    it('stays hidden when the button has no offsetParent to position against', async () => {
      Object.defineProperty(wrapper.element, 'offsetParent', { configurable: true, value: null });
      await simulateSelectText();
      expect(findButton().isVisible()).toBe(false);
    });

    describe('toggle position', () => {
      beforeEach(() => {
        Object.defineProperty(wrapper.element, 'offsetParent', {
          configurable: true,
          value: { getBoundingClientRect: () => ({ top: OFFSET_PARENT_TOP }) },
        });
      });

      it('is positioned correctly at the start of the selection', async () => {
        const getRangeAt = getRangeAtMock((position) => {
          return position === 0 ? SELECTION_START_POSITION : SELECTION_END_POSITION;
        });
        const getSelection = getSelectionMock({ getRangeAt });
        await simulateSelectText({ getSelection });
        expect(wrapper.element.style.top).toBe(`${SELECTION_START_POSITION - OFFSET_PARENT_TOP}px`);
      });

      it('is positioned correctly at the end of the selection', async () => {
        const getRangeAt = getRangeAtMock((position) => {
          return position === 0 ? SELECTION_END_POSITION : SELECTION_START_POSITION;
        });
        const getSelection = getSelectionMock({ getRangeAt });
        await simulateSelectText({ getSelection });
        expect(wrapper.element.style.top).toBe(`${SELECTION_START_POSITION - OFFSET_PARENT_TOP}px`);
      });
    });
  });

  describe('selectionchange event listener', () => {
    let addEventListenerSpy;
    let removeEventListenerSpy;

    beforeEach(() => {
      addEventListenerSpy = jest.spyOn(document, 'addEventListener');
      removeEventListenerSpy = jest.spyOn(document, 'removeEventListener');
      createComponent();
    });

    afterEach(() => {
      addEventListenerSpy.mockRestore();
      removeEventListenerSpy.mockRestore();
    });

    it('sets up the `selectionchange` event listener', () => {
      expect(addEventListenerSpy).toHaveBeenCalledWith('selectionchange', expect.any(Function));
      expect(removeEventListenerSpy).not.toHaveBeenCalled();
    });

    it('removes the event listener when destroyed', () => {
      wrapper.destroy();
      expect(removeEventListenerSpy).toHaveBeenCalledWith('selectionchange', expect.any(Function));
    });
  });

  describe('interaction', () => {
    beforeEach(() => {
      createComponent();
    });

    it('calls the `sendDuoChatCommand` code request', async () => {
      const selectedText = 'const foo = "bar";';
      await simulateSelectText({
        getSelection: getSelectionMock({ toString: () => selectedText }),
      });
      await requestExplanation();
      expect(sendDuoChatCommand).toHaveBeenCalledWith({
        question: GENIE_CHAT_EXPLAIN_MESSAGE,
        resourceId,
        variables: {
          currentFileContext: {
            fileName: filePath,
            selectedText,
          },
        },
        agenticPrompt: `${i18n.AGENTIC_PROMPT_EXPLAIN_CODE}\n\n\`\`\`\n${selectedText}\n\`\`\``,
      });
    });
  });

  describe('Lines highlighting', () => {
    beforeEach(() => {
      createComponent();
    });

    it('initiates LineHighlighter', () => {
      expect(LineHighlighter).toHaveBeenCalled();
    });

    it('calls highlightRange with expected range', async () => {
      await simulateSelectText();
      await requestExplanation();
      expect(lineHighlighter.highlightRange).toHaveBeenCalledWith([1, 1]);
    });

    it('calls clearHighlight to clear previous selection', async () => {
      await simulateSelectText();
      await requestExplanation();
      expect(lineHighlighter.clearHighlight).toHaveBeenCalledTimes(1);
    });

    it('does not call highlight range when no line found', async () => {
      document.getElementById(`${LINE_ID}`).classList.remove('line');
      await simulateSelectText();
      await requestExplanation();
      expect(lineHighlighter.highlightRange).not.toHaveBeenCalled();
    });
  });

  // Renders the real source viewer `Chunk` so the line-number lookup in ai_genie is
  // exercised against the actual blob DOM contract instead of a hand-written fixture.
  // After the two-layer source-viewer refactor the selectable `.line` element no longer
  // carries an `id`; clicking explain must still open the chat (send `/explain`) rather
  // than throwing while it tries to read a line number for the (optional) line highlight.
  describe('explain code against the real source viewer DOM', () => {
    let chunkWrapper;

    const mountRealChunk = () =>
      shallowMountExtended(Chunk, {
        store: new Vuex.Store({ state: {}, mutations: {} }),
        propsData: {
          isHighlighted: true,
          rawContent: 'class',
          highlightedContent:
            '<div id="LC1" class="line"><span class="hljs-keyword">class</span></div>',
          totalLines: 1,
          blobPath: 'test.rb',
          blamePath: '/project/blame/main/test.rb',
        },
        provide: {
          blameActions: { activateInlineBlame: jest.fn() },
          glFeatures: { inlineBlame: false },
        },
      });

    afterEach(() => {
      chunkWrapper?.destroy();
    });

    it('sends the `/explain` command when the selected line has no id', async () => {
      createComponent();
      chunkWrapper = mountRealChunk();
      const selectableLine = chunkWrapper.findByTestId('content').element;

      // Guard the contract: the real source viewer renders the selectable line with the
      // `.line` class but no `id`. If this changes, revisit getLineNumber together.
      expect(selectableLine.matches('.line')).toBe(true);
      expect(selectableLine.id).toBe('');

      const selectionNode = selectableLine.firstChild;
      await simulateSelectText({
        getSelection: {
          ...getSelectionMock({ toString: () => 'class' }),
          anchorNode: selectionNode,
          focusNode: selectionNode,
        },
      });
      await requestExplanation();

      expect(sendDuoChatCommand).toHaveBeenCalled();
    });
  });
});
