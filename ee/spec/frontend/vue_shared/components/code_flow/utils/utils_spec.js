import {
  sortCodeBlocks,
  updateCodeBlocks,
  updateLinesToMarker,
  normalizeCodeFlowsInfo,
  createHighlightSourcesInfo,
  createSourceBlockHighlightInfo,
  scrollToSpecificCodeFlow,
  markdownRowContent,
  markdownRowNumber,
  markdownStepNumber,
} from 'ee/vue_shared/components/code_flow/utils/utils';

jest.mock('~/vue_shared/components/source_viewer/workers/highlight_utils', () => ({
  ...jest.requireActual('~/vue_shared/components/source_viewer/workers/highlight_utils'),
  splitByLineBreaks: jest.fn((text) => text.split('\n')),
}));

const mockQuerySelector = jest.fn();
const mockGetElementById = jest.fn();
const mockScrollTo = jest.fn();
document.querySelector = mockQuerySelector;
document.getElementById = mockGetElementById;

describe('updateCodeBlocks', () => {
  it('should return an empty array when input is empty', () => {
    expect(updateCodeBlocks([])).toEqual([]);
  });

  it('should update highlight info with step numbers', () => {
    const input = [
      {
        blockStartLine: 1,
        blockEndLine: 10,
        highlightInfo: [
          { index: 0, startLine: 1, endLine: 2 },
          { index: 1, startLine: 8, endLine: 10 },
        ],
      },
    ];
    const expected = [
      {
        blockStartLine: 1,
        blockEndLine: 10,
        highlightInfo: [
          { index: 0, startLine: 1, endLine: 2, stepNumber: 1 },
          { index: 1, startLine: 8, endLine: 10, stepNumber: 2 },
        ],
      },
    ];
    expect(updateCodeBlocks(input)).toEqual(expected);
  });

  it('should merge and sort blocks', () => {
    const input = [
      {
        blockStartLine: 4,
        blockEndLine: 6,
        highlightInfo: [{ index: 2 }],
      },
      {
        blockStartLine: 1,
        blockEndLine: 3,
        highlightInfo: [{ index: 0 }, { index: 1 }],
      },
    ];
    const expected = [
      {
        blockStartLine: 1,
        blockEndLine: 6,
        highlightInfo: [
          { index: 0, stepNumber: 1 },
          { index: 1, stepNumber: 2 },
          { index: 2, stepNumber: 3 },
        ],
      },
    ];
    expect(updateCodeBlocks(input)).toEqual(expected);
  });
});

describe('sortCodeBlocks', () => {
  it('should sort blocks by start line', () => {
    const input = [
      { blockStartLine: 5, blockEndLine: 8, highlightInfo: [] },
      { blockStartLine: 1, blockEndLine: 3, highlightInfo: [] },
    ];
    const result = sortCodeBlocks(input);
    expect(result[0].blockStartLine).toBe(1);
    expect(result[1].blockStartLine).toBe(5);
  });

  it('should merge adjacent blocks', () => {
    const input = [
      { blockStartLine: 1, blockEndLine: 3, highlightInfo: [{ id: 1 }] },
      { blockStartLine: 4, blockEndLine: 6, highlightInfo: [{ id: 2 }] },
    ];
    const result = sortCodeBlocks(input);
    expect(result).toHaveLength(1);
    expect(result[0].blockEndLine).toBe(6);
    expect(result[0].highlightInfo).toEqual([{ id: 1 }, { id: 2 }]);
  });

  it('should merge overlapping blocks', () => {
    const input = [
      { blockStartLine: 1, blockEndLine: 4, highlightInfo: [{ id: 1 }] },
      { blockStartLine: 3, blockEndLine: 6, highlightInfo: [{ id: 2 }] },
    ];
    const result = sortCodeBlocks(input);
    expect(result).toHaveLength(1);
    expect(result[0].blockStartLine).toBe(1);
    expect(result[0].blockEndLine).toBe(6);
    expect(result[0].highlightInfo).toEqual([{ id: 1 }, { id: 2 }]);
  });

  it('should not merge non-adjacent blocks', () => {
    const input = [
      { blockStartLine: 1, blockEndLine: 3, highlightInfo: [{ id: 1 }] },
      { blockStartLine: 5, blockEndLine: 7, highlightInfo: [{ id: 2 }] },
    ];
    const result = sortCodeBlocks(input);
    expect(result).toHaveLength(2);
  });
});

describe('updateLinesToMarker', () => {
  it('should create correct mapping for single line highlights', () => {
    const input = [
      {
        highlightInfo: [
          { startLine: 1, info: 'Line 1' },
          { startLine: 3, info: 'Line 3' },
        ],
      },
    ];
    const result = updateLinesToMarker(input);
    expect(result).toEqual({
      1: [{ startLine: 1, info: 'Line 1' }],
      3: [{ startLine: 3, info: 'Line 3' }],
    });
  });

  it('should create correct mapping for multi-line highlights', () => {
    const input = [
      {
        highlightInfo: [{ startLine: 1, endLine: 3, info: 'Lines 1-3' }],
      },
    ];
    const result = updateLinesToMarker(input);
    expect(result).toEqual({
      1: [{ startLine: 1, endLine: 3, info: 'Lines 1-3' }],
      2: [{ startLine: 1, endLine: 3, info: 'Lines 1-3' }],
      3: [{ startLine: 1, endLine: 3, info: 'Lines 1-3' }],
    });
  });

  it('should handle multiple code blocks', () => {
    const input = [
      {
        highlightInfo: [{ startLine: 1, endLine: 2, info: 'Block 1' }],
      },
      {
        highlightInfo: [{ startLine: 4, info: 'Block 2' }],
      },
    ];
    const result = updateLinesToMarker(input);
    expect(result).toEqual({
      1: [{ startLine: 1, endLine: 2, info: 'Block 1' }],
      2: [{ startLine: 1, endLine: 2, info: 'Block 1' }],
      4: [{ startLine: 4, info: 'Block 2' }],
    });
  });

  it('should handle overlapping highlights', () => {
    const input = [
      {
        highlightInfo: [
          { startLine: 1, endLine: 3, info: 'Block 1' },
          { startLine: 2, endLine: 4, info: 'Block 2' },
        ],
      },
    ];
    const result = updateLinesToMarker(input);
    expect(result).toEqual({
      1: [{ startLine: 1, endLine: 3, info: 'Block 1' }],
      2: [
        { startLine: 1, endLine: 3, info: 'Block 1' },
        { startLine: 2, endLine: 4, info: 'Block 2' },
      ],
      3: [
        { startLine: 1, endLine: 3, info: 'Block 1' },
        { startLine: 2, endLine: 4, info: 'Block 2' },
      ],
      4: [{ startLine: 2, endLine: 4, info: 'Block 2' }],
    });
  });

  it('should return an empty object for empty input', () => {
    const result = updateLinesToMarker([]);
    expect(result).toEqual({});
  });
});

describe('normalizeCodeFlowsInfo', () => {
  it('should normalize code flow information correctly', () => {
    const details = {
      items: [
        [
          { fileLocation: { fileName: 'file1.js' } },
          { fileLocation: { fileName: 'file2.js' } },
          { fileLocation: { fileName: 'file1.js' } },
        ],
      ],
    };

    const result = normalizeCodeFlowsInfo(details);

    expect(result).toEqual({
      'file1.js': [
        { index: 0, fileLocation: { fileName: 'file1.js' } },
        { index: 2, fileLocation: { fileName: 'file1.js' } },
      ],
      'file2.js': [{ index: 1, fileLocation: { fileName: 'file2.js' } }],
    });
  });

  it('should return an empty object if details are undefined', () => {
    const result = normalizeCodeFlowsInfo(undefined);
    expect(result).toEqual({});
  });
});

describe('createHighlightSourcesInfo', () => {
  it('should create highlight sources information correctly', () => {
    const normalizedCodeFlows = {
      'file1.js': [{ index: 0, fileLocation: { fileName: 'file1.js', lineStart: 5, lineEnd: 10 } }],
    };
    const rawTextBlobs = {
      'file1.js':
        'line1\nline2\nline3\nline4\nline5\nline6\nline7\nline8\nline9\nline10\nline11\nline12',
    };

    const result = createHighlightSourcesInfo(normalizedCodeFlows, rawTextBlobs);

    expect(result).toEqual({
      'file1.js': [
        {
          blockStartLine: 2,
          blockEndLine: 12,
          highlightInfo: [
            {
              index: 0,
              startLine: 5,
              endLine: 10,
            },
          ],
        },
      ],
    });
  });

  it('should return an empty object if inputs are undefined', () => {
    const result = createHighlightSourcesInfo(undefined, undefined);
    expect(result).toEqual({});
  });
});

describe('createSourceBlockHighlightInfo', () => {
  it('should create source block highlight information correctly', () => {
    const index = 0;
    const fileLocation = { fileName: 'file1.js', lineStart: 5, lineEnd: 10 };
    const rawTextBlob =
      'line1\nline2\nline3\nline4\nline5\nline6\nline7\nline8\nline9\nline10\nline11\nline12';

    const result = createSourceBlockHighlightInfo(index, fileLocation, rawTextBlob);

    expect(result).toEqual({
      blockStartLine: 2,
      blockEndLine: 12,
      highlightInfo: [
        {
          index: 0,
          startLine: 5,
          endLine: 10,
        },
      ],
    });
  });

  it('should handle cases where lineEnd is not provided', () => {
    const index = 0;
    const fileLocation = { fileName: 'file1.js', lineStart: 5 };
    const rawTextBlob = 'line1\nline2\nline3\nline4\nline5\nline6\nline7';

    const result = createSourceBlockHighlightInfo(index, fileLocation, rawTextBlob);

    expect(result).toEqual({
      blockStartLine: 2,
      blockEndLine: 7,
      highlightInfo: [
        {
          index: 0,
          startLine: 5,
          endLine: undefined,
        },
      ],
    });
  });

  it('should handle edge cases with line numbers', () => {
    const index = 0;
    const fileLocation = { fileName: 'file1.js', lineStart: 1, lineEnd: 10 };
    const rawTextBlob = 'line1\nline2\nline3';

    const result = createSourceBlockHighlightInfo(index, fileLocation, rawTextBlob);

    expect(result).toEqual({
      blockStartLine: 1,
      blockEndLine: 3,
      highlightInfo: [
        {
          index: 0,
          startLine: 1,
          endLine: 10,
        },
      ],
    });
  });
});

describe('scrollToSpecificCodeFlow', () => {
  beforeEach(() => {
    const mockElement = {
      getBoundingClientRect: jest.fn(() => ({
        top: 300,
      })),
      clientHeight: 20,
    };

    const mockSubScroller = {
      getBoundingClientRect: jest.fn(() => ({
        top: 100,
      })),
      scrollTo: mockScrollTo,
      scrollTop: 50,
      clientHeight: 500,
    };

    mockQuerySelector.mockImplementation((selector) => {
      if (selector.startsWith('[id^=TEXT-MARKER')) {
        return mockElement;
      }
      return null;
    });

    mockGetElementById.mockImplementation((id) => {
      if (id === 'code-flows-container') {
        return mockSubScroller;
      }
      return null;
    });
  });

  afterEach(() => {
    jest.resetAllMocks();
  });

  it('should scroll to the specific code flow when element is found', () => {
    scrollToSpecificCodeFlow(5);
    expect(mockQuerySelector).toHaveBeenCalledWith('[id^=TEXT-MARKER-5]');
    expect(mockGetElementById).toHaveBeenCalledWith('code-flows-container');
    expect(mockScrollTo).toHaveBeenCalledWith({
      top: 10, // (300 - 100 + 50) - 500/2 + 20/2
      behavior: 'smooth',
    });
  });

  it('should not scroll when the specific element is not found', () => {
    mockQuerySelector.mockImplementation((selector) => {
      if (selector === '[id=code-flows-container]') {
        return {
          getBoundingClientRect: jest.fn(() => ({
            top: 100,
          })),
          scrollTo: mockScrollTo,
          scrollTop: 50,
          clientHeight: 500,
        };
      }
      return null; // Simulating element not found
    });
    scrollToSpecificCodeFlow(10);
    expect(mockQuerySelector).toHaveBeenCalledWith('[id^=TEXT-MARKER-10]');
    expect(mockScrollTo).not.toHaveBeenCalled();
  });

  it('should handle different step numbers', () => {
    scrollToSpecificCodeFlow(1);
    expect(mockQuerySelector).toHaveBeenCalledWith('[id^=TEXT-MARKER-1]');

    scrollToSpecificCodeFlow(100);
    expect(mockQuerySelector).toHaveBeenCalledWith('[id^=TEXT-MARKER-100]');
  });
});

describe('markdownRowContent', () => {
  const createMockElement = (id, className = '') => {
    const el = document.createElement('div');
    el.setAttribute('id', id);
    if (className) {
      el.classList.add(className);
    }
    document.body.appendChild(el);
    return el;
  };

  afterEach(() => {
    document.body.innerHTML = '';
  });

  it('should remove `selected-inline-section-marker` class from all elements starting with `TEXT-MARKER-`', () => {
    const mockEl1 = createMockElement('TEXT-MARKER-1', 'selected-inline-section-marker');
    const mockEl2 = createMockElement('TEXT-MARKER-2', 'selected-inline-section-marker');
    const mockEl3 = createMockElement('TEXT-MARKER-3', 'some-other-class');
    markdownRowContent(1);
    expect(mockEl1.classList.contains('selected-inline-section-marker')).toBe(false);
    expect(mockEl2.classList.contains('selected-inline-section-marker')).toBe(false);
    expect(mockEl3.classList.contains('selected-inline-section-marker')).toBe(false);
  });

  it('should add `selected-inline-section-marker` class to elements matching the selectedStepNumber', () => {
    const mockEl1 = createMockElement('TEXT-MARKER-1-L7');
    const mockEl2 = createMockElement('TEXT-MARKER-2-L7');
    const mockEl3 = createMockElement('TEXT-MARKER-1,2-L7');
    markdownRowContent(1);
    expect(mockEl1.classList.contains('selected-inline-section-marker')).toBe(true);
    expect(mockEl2.classList.contains('selected-inline-section-marker')).toBe(false);
    expect(mockEl3.classList.contains('selected-inline-section-marker')).toBe(true);
  });

  it('should do nothing if no element matches the selectedStepNumber', () => {
    const mockEl1 = createMockElement('TEXT-MARKER-2-L7');
    markdownRowContent(3);
    expect(mockEl1.classList.contains('selected-inline-section-marker')).toBe(false);
  });
});

describe('markdownStepNumber', () => {
  const createMockElement = (id, innerHTML = '') => {
    const el = document.createElement('span');
    el.setAttribute('id', id);
    el.setAttribute('class', '');
    if (innerHTML) {
      el.innerHTML = innerHTML;
    }
    document.body.appendChild(el);
    return el;
  };

  afterEach(() => {
    document.body.innerHTML = '';
  });

  it('should remove `selected-inline-item-mark` class from all span elements inside matching `TEXT-MARKER-` elements', () => {
    const mockEl1 = createMockElement(
      `TEXT-MARKER-1`,
      '<span class="inline-item-mark selected-inline-item-mark"></span>',
    );
    const mockEl2 = createMockElement(
      `TEXT-MARKER-2`,
      '<span class="inline-item-mark selected-inline-item-mark"></span>',
    );
    markdownStepNumber(1);
    const span1 = mockEl1.querySelector('span.inline-item-mark');
    const span2 = mockEl2.querySelector('span.inline-item-mark');
    expect(span1.classList.contains('selected-inline-item-mark')).toBe(false);
    expect(span2.classList.contains('selected-inline-item-mark')).toBe(false);
  });

  it('should add `selected-inline-item-mark` and `gs` classes to the element matching selectedStepNumber', () => {
    const matchingEl = createMockElement(`TEXT-SPAN-MARKER-1`);
    markdownStepNumber(1);
    expect(matchingEl.classList.contains('selected-inline-item-mark')).toBe(true);
    expect(matchingEl.classList.contains('gs')).toBe(true);
  });

  it('should do nothing if no element matches the selectedStepNumber', () => {
    const nonMatchingEl = createMockElement(`TEXT-SPAN-MARKER-2`);
    markdownStepNumber(1);
    expect(nonMatchingEl.classList.contains('selected-inline-item-mark')).toBe(false);
    expect(nonMatchingEl.classList.contains('gs')).toBe(false);
  });
});

describe('markdownRowNumber', () => {
  const createMockElement = (id, classNames = '') => {
    const el = document.createElement('div');
    el.setAttribute('id', id);
    el.className = classNames;
    document.body.appendChild(el);
    return el;
  };

  afterEach(() => {
    document.body.innerHTML = '';
  });

  it('should remove `selected-inline-number-mark` and add `unselected-inline-number-mark` to all elements with id starting with "NUM-MARKER-"', () => {
    const mockEl1 = createMockElement('NUM-MARKER-1', 'selected-inline-number-mark');
    const mockEl2 = createMockElement('NUM-MARKER-2', 'selected-inline-number-mark');
    markdownRowNumber(1);
    expect(mockEl1.classList.contains('selected-inline-number-mark')).toBe(false);
    expect(mockEl1.classList.contains('unselected-inline-number-mark')).toBe(true);
    expect(mockEl2.classList.contains('selected-inline-number-mark')).toBe(false);
    expect(mockEl2.classList.contains('unselected-inline-number-mark')).toBe(true);
  });

  it('should add `selected-inline-number-mark` and remove `unselected-inline-number-mark` to element matching selectedStepNumber', () => {
    const matchingEl = createMockElement('NUM-MARKER-1-L8', 'unselected-inline-number-mark');
    markdownRowNumber(1);
    expect(matchingEl.classList.contains('selected-inline-number-mark')).toBe(true);
    expect(matchingEl.classList.contains('unselected-inline-number-mark')).toBe(false);
  });

  it('should do nothing if no element matches the selectedStepNumber', () => {
    const nonMatchingEl = createMockElement('NUM-MARKER-2-L8', 'unselected-inline-number-mark');
    markdownRowNumber(1);
    expect(nonMatchingEl.classList.contains('selected-inline-number-mark')).toBe(false);
    expect(nonMatchingEl.classList.contains('unselected-inline-number-mark')).toBe(true);
  });
});
