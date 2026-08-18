import { ref, nextTick } from 'vue';
import { resetHTMLFixture, setHTMLFixture } from 'helpers/fixtures';
import { DiffFile } from '~/rapid_diffs/web_components/diff_file';
import { EXPANDED_LINES } from '~/rapid_diffs/adapter_events';
import { createLineInlineFindingsAdapter } from 'ee/rapid_diffs/adapters/line_inline_findings';
import { useCodeQuality } from '~/rapid_diffs/stores/code_quality';
import { pinia } from '~/pinia/instance';

jest.mock('~/pinia/instance', () => {
  // eslint-disable-next-line global-require
  const { createPinia, setActivePinia } = require('pinia');
  const instance = createPinia();
  setActivePinia(instance);
  return { pinia: instance };
});

const newPath = 'app/foo.rb';

describe('lineInlineFindingsAdapter', () => {
  let store;
  let sastFindings;

  const setupFixture = ({ filePath = newPath } = {}) => {
    const fileData = { viewer: 'text_inline', oldPath: newPath, newPath: filePath };
    setHTMLFixture(`
      <diff-file id="abc" data-file-data='${JSON.stringify(fileData)}'>
        <div>
          <table>
            <tbody>
              <tr data-hunk-lines>
                <td data-position="old"></td>
                <td data-position="new"></td>
                <td data-position="new" class="rd-line-content">
                  <span data-line-inline-findings="5"></span>
                  <pre class="rd-line-text"></pre>
                </td>
              </tr>
              <tr data-hunk-lines>
                <td data-position="old"></td>
                <td data-position="new"></td>
                <td data-position="new" class="rd-line-content">
                  <span data-line-inline-findings="6"></span>
                  <pre class="rd-line-text"></pre>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </diff-file>
    `);
  };

  const mountWithAdapter = () => {
    document.querySelector('diff-file').mount({
      adapterConfig: { text_inline: [createLineInlineFindingsAdapter({ sastFindings })] },
      appData: {},
      observe: jest.fn(),
      unobserve: jest.fn(),
    });
  };

  const getSlots = () => document.querySelectorAll('[data-line-inline-findings]');
  const getTrigger = (slot) => slot.querySelector('button[data-click="showInlineFindings"]');
  const getStaticIcon = (slot) => slot.querySelector('svg');
  const clickSlot = (slot) => {
    const button = getTrigger(slot);
    let event;
    button.addEventListener(
      'click',
      (e) => {
        event = e;
      },
      { once: true },
    );
    button.click();
    document.querySelector('diff-file').onClick(event);
  };

  const setCodeQuality = (files) => {
    store.files = files;
    store.loaded = true;
  };

  const sastFinding = (line) => ({
    description: 'SQL injection',
    severity: 'High',
    state: 'detected',
    title: 'SQLi',
    details: {},
    identifiers: [],
    foundByPipelineIid: '1',
    location: { file: newPath, startLine: `${line}` },
  });

  beforeAll(() => {
    customElements.define('diff-file', DiffFile);
  });

  beforeEach(() => {
    store = useCodeQuality(pinia);
    store.$reset();
    sastFindings = ref(null);
  });

  afterEach(() => {
    resetHTMLFixture();
  });

  it('does nothing when no findings have loaded', () => {
    setupFixture();
    mountWithAdapter();

    getSlots().forEach((slot) => {
      expect(slot.dataset.inlineFindingsDecorated).toBeUndefined();
      expect(getTrigger(slot)).toBe(null);
    });
  });

  it('renders a static, clickable severity icon at rest only on lines with code quality findings', async () => {
    setupFixture();
    mountWithAdapter();

    setCodeQuality({ [newPath]: [{ line: 5, description: 'Method too long', severity: 'major' }] });
    await nextTick();

    const [slot5, slot6] = getSlots();
    expect(slot5.dataset.inlineFindingsDecorated).toBe('true');
    expect(getTrigger(slot5)).not.toBe(null);
    expect(getTrigger(slot5).getAttribute('aria-label')).toBe('1 finding detected');
    expect(getStaticIcon(slot5).classList).toContain('s14');
    expect(slot5.destroyFindings).toBeUndefined();

    expect(slot6.dataset.inlineFindingsDecorated).toBeUndefined();
    expect(getTrigger(slot6)).toBe(null);
  });

  it('renders a trigger on lines carrying SAST findings', async () => {
    setupFixture();
    mountWithAdapter();

    sastFindings.value = { added: [sastFinding(6)] };
    await nextTick();

    const [slot5, slot6] = getSlots();
    expect(getTrigger(slot5)).toBe(null);
    expect(slot6.dataset.inlineFindingsDecorated).toBe('true');
    expect(getTrigger(slot6)).not.toBe(null);
  });

  it('counts code quality and SAST findings together on the same line', async () => {
    setupFixture();
    mountWithAdapter();

    setCodeQuality({ [newPath]: [{ line: 5, description: 'Method too long', severity: 'major' }] });
    sastFindings.value = { added: [sastFinding(5)] };
    await nextTick();

    const [slot5] = getSlots();
    expect(getTrigger(slot5).getAttribute('aria-label')).toBe('2 findings detected');
  });

  it('flags the file so every line reserves the trigger slot table-wide', async () => {
    setupFixture();
    mountWithAdapter();
    const diffElement = document.querySelector('diff-file > div');

    expect(diffElement.dataset.inlineFindingsLoaded).toBeUndefined();

    setCodeQuality({ [newPath]: [{ line: 5, description: 'x', severity: 'major' }] });
    await nextTick();

    expect(diffElement.dataset.inlineFindingsLoaded).toBe('true');
  });

  it('does not reserve the gutter when SAST findings belong only to other files', async () => {
    setupFixture();
    mountWithAdapter();
    const diffElement = document.querySelector('diff-file > div');

    sastFindings.value = {
      added: [{ ...sastFinding(5), location: { file: 'other/file.rb', startLine: '5' } }],
    };
    await nextTick();

    expect(diffElement.dataset.inlineFindingsLoaded).toBeUndefined();
    getSlots().forEach((slot) => expect(slot.dataset.inlineFindingsDecorated).toBeUndefined());
  });

  it('mounts the interactive dropdown only when the line is clicked', async () => {
    setupFixture();
    mountWithAdapter();

    setCodeQuality({ [newPath]: [{ line: 5, description: 'Method too long', severity: 'major' }] });
    await nextTick();

    const [slot5] = getSlots();
    expect(slot5.destroyFindings).toBeUndefined();

    clickSlot(slot5);

    expect(typeof slot5.destroyFindings).toBe('function');
    expect(getTrigger(slot5)).toBe(null);
  });

  it('decorates lines revealed by EXPANDED_LINES', async () => {
    setupFixture();
    mountWithAdapter();

    setCodeQuality({ [newPath]: [{ line: 5, description: 'x', severity: 'minor' }] });
    await nextTick();

    const newRow = document.createElement('tr');
    newRow.dataset.hunkLines = '';
    newRow.innerHTML = `
      <td data-position="old"></td>
      <td data-position="new"></td>
      <td data-position="new" class="rd-line-content">
        <span data-line-inline-findings="7"></span>
        <pre class="rd-line-text"></pre>
      </td>
    `;
    document.querySelector('tbody').appendChild(newRow);
    store.files = {
      [newPath]: [
        { line: 5, description: 'x', severity: 'minor' },
        { line: 7, description: 'Unused variable', severity: 'info' },
      ],
    };
    document.querySelector('diff-file').trigger(EXPANDED_LINES);

    const slot7 = document.querySelector('[data-line-inline-findings="7"]');
    expect(slot7.dataset.inlineFindingsDecorated).toBe('true');
    expect(getTrigger(slot7)).not.toBe(null);
  });

  it('does nothing when the file has no newPath', () => {
    setupFixture({ filePath: '' });
    mountWithAdapter();

    setCodeQuality({ '': [{ line: 5, description: 'x', severity: 'major' }] });

    getSlots().forEach((slot) => {
      expect(slot.dataset.inlineFindingsDecorated).toBeUndefined();
    });
  });
});
