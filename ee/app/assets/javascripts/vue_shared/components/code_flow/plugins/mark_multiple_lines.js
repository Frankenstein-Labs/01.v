import {
  inlineItemMark,
  inlineSectionMarker,
  textMarkerIdPrefix,
  textSpanMarkerIdPrefix,
} from 'ee/vue_shared/components/code_flow/utils/constants';

/**
 * Highlight.js plugin for wrapping lines in the correct classes and attributes.
 * Needed to highlight a large amount of lines
 *
 * Plugin API: https://github.com/highlightjs/highlight.js/blob/main/docs/plugin-api.rst
 *
 * @param {String} content - represent highlighted line of code
 * @param {number} lineNum - represent highlighted line number
 * @param {Object} markLineInfo - highlighting info for the current line
 */
function markLinesWithDiv(content, lineNum, markLineInfo) {
  let stepNumberSpan = '';
  let stepNumberSpanNone = '';
  let wrappedLine = content;

  // Combines an array of step numbers into a comma-separated string
  const stepNumbersArr = markLineInfo?.map((markLine) => markLine.stepNumber);
  const stepNumbers = stepNumbersArr?.map(String).join(',') ?? '';

  markLineInfo?.forEach((markLine) => {
    stepNumberSpan +=
      lineNum === markLine.startLine
        ? `<span id="${textSpanMarkerIdPrefix}${markLine.stepNumber}" class="${inlineItemMark}">${markLine.stepNumber}</span>`
        : '';
    stepNumberSpanNone +=
      lineNum !== markLine.startLine
        ? `<span id="${textSpanMarkerIdPrefix}${markLine.stepNumber}" class="${inlineItemMark} gl-opacity-0">${markLine.stepNumber}</span>`
        : '';
  });

  if (markLineInfo) {
    const contentStartIndex = content.indexOf(content.trimStart());
    wrappedLine = `${content.slice(
      0,
      contentStartIndex,
    )}${stepNumberSpanNone}<span id="${textMarkerIdPrefix}${
      stepNumbers
    }-L${lineNum}" class="${inlineSectionMarker}">${stepNumberSpan}${content.slice(contentStartIndex)}</span>`;
  }
  return `<div class="line">${wrappedLine}</div>`;
}

export default (result, lineToMarkersInfo) => {
  // eslint-disable-next-line no-param-reassign
  result.value = result.value
    .split(/\r?\n/)
    .map((content, index) => markLinesWithDiv(content, index + 1, lineToMarkersInfo?.[index + 1]))
    .join('\n');
};
