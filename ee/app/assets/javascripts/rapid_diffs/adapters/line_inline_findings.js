import Vue, { watch } from 'vue';
import { groupBy } from 'lodash-es';
import { n__ } from '~/locale';
import { convertObjectPropsToCamelCase, spriteIconElement } from '~/lib/utils/common_utils';
import { pinia } from '~/pinia/instance';
import { EXPANDED_LINES, MOUNTED } from '~/rapid_diffs/adapter_events';
import { useCodeQuality } from '~/rapid_diffs/stores/code_quality';
import { groupSastFindingsByLine } from 'ee/diffs/components/inline_findings_utils';
import { SEVERITIES as CODE_QUALITY_SEVERITIES } from '~/ci/reports/codequality_report/constants';
import { SEVERITIES as SAST_SEVERITIES } from '~/ci/reports/sast/constants';
import InlineFindingsGutterIconDropdown from 'ee/diffs/components/inline_findings_gutter_icon_dropdown.vue';

const CLICK_ACTION = 'showInlineFindings';

const TOGGLE_ICON_SIZE = 14;
const TOGGLE_ICON_CLASS = 'inline-findings-severity-icon';

const normalize = (severities, severity) => (severities[severity] ? severity : 'unknown');

function buildSeverityIcon({ severities, severity }) {
  const { name, class: colorClass } = severities[normalize(severities, severity)];
  return spriteIconElement(name, `gl-icon s${TOGGLE_ICON_SIZE} ${TOGGLE_ICON_CLASS} ${colorClass}`);
}

function primarySeverityIcon({ codeQuality, sast }) {
  const finding = codeQuality[0] || sast[0];
  if (!finding) return null;
  const severities = codeQuality.length ? CODE_QUALITY_SEVERITIES : SAST_SEVERITIES;
  return buildSeverityIcon({ severities, severity: finding.severity });
}

function buildTrigger({ codeQuality, sast }) {
  const total = codeQuality.length + sast.length;
  const button = document.createElement('button');
  button.type = 'button';
  button.className = 'rd-inline-findings-toggle';
  button.dataset.click = CLICK_ACTION;
  button.setAttribute(
    'aria-label',
    n__('InlineFindings|1 finding detected', 'InlineFindings|%d findings detected', total),
  );
  const icon = primarySeverityIcon({ codeQuality, sast });
  if (icon) button.appendChild(icon);
  return button;
}

/* eslint-disable no-param-reassign */
function decorateSlot(slot, findings) {
  if (slot.dataset.inlineFindingsDecorated) return;
  slot.dataset.inlineFindingsDecorated = 'true';
  slot.appendChild(buildTrigger(findings));
}

function mountFindings(slot, filePath, { codeQuality, sast }) {
  const placeholder = document.createElement('div');
  slot.replaceChildren(placeholder);
  const instance = new Vue({
    el: placeholder,
    pinia,
    name: 'InlineFindingsGutterRoot',
    render: (h) =>
      h(InlineFindingsGutterIconDropdown, {
        class: 'rd-inline-findings-toggle',
        props: {
          filePath,
          codeQuality: codeQuality.map((finding) => convertObjectPropsToCamelCase(finding)),
          sast,
          startOpened: true,
          compact: true,
        },
      }),
  });
  slot.destroyFindings = () => instance.$destroy();
}
/* eslint-enable no-param-reassign */

function decorate(diffElement, { codeQualityFindings, sastReport, filePath }) {
  const codeQualityByLine = groupBy(codeQualityFindings || [], 'line');
  const sastByLine = groupSastFindingsByLine(filePath, sastReport);
  if (!codeQualityFindings && Object.keys(sastByLine).length === 0) return;

  // eslint-disable-next-line no-param-reassign
  diffElement.dataset.inlineFindingsLoaded = 'true';

  diffElement
    .querySelectorAll('[data-line-inline-findings]:not([data-inline-findings-decorated])')
    .forEach((slot) => {
      const lineNumber = slot.dataset.lineInlineFindings;
      const findings = {
        codeQuality: codeQualityByLine[lineNumber] || [],
        sast: sastByLine[lineNumber] || [],
      };
      if (findings.codeQuality.length || findings.sast.length) decorateSlot(slot, findings);
    });
}

export const createLineInlineFindingsAdapter = ({ sastFindings }) => ({
  [MOUNTED](addCleanup) {
    const { diffElement } = this;
    const { newPath } = this.data;
    if (!newPath) return;

    const store = useCodeQuality(pinia);
    const stopWatch = watch(
      () => [store.findingsForFile(newPath), sastFindings.value],
      ([codeQualityFindings, sastReport]) =>
        decorate(diffElement, { codeQualityFindings, sastReport, filePath: newPath }),
      { immediate: true },
    );
    addCleanup(() => {
      stopWatch();
      diffElement
        .querySelectorAll('[data-line-inline-findings]')
        .forEach((slot) => slot.destroyFindings?.());
    });
  },
  [EXPANDED_LINES]() {
    const { newPath } = this.data;
    if (!newPath) return;
    const store = useCodeQuality(pinia);
    decorate(this.diffElement, {
      codeQualityFindings: store.findingsForFile(newPath),
      sastReport: sastFindings.value,
      filePath: newPath,
    });
  },
  clicks: {
    [CLICK_ACTION](event, button) {
      const { newPath } = this.data;
      if (!newPath) return;
      const slot = button.closest('[data-line-inline-findings]');
      if (!slot) return;
      const lineNumber = slot.dataset.lineInlineFindings;
      const findings = {
        codeQuality:
          groupBy(useCodeQuality(pinia).findingsForFile(newPath) || [], 'line')[lineNumber] || [],
        sast: groupSastFindingsByLine(newPath, sastFindings.value)[lineNumber] || [],
      };
      if (findings.codeQuality.length || findings.sast.length) {
        mountFindings(slot, newPath, findings);
      }
    },
  },
});
