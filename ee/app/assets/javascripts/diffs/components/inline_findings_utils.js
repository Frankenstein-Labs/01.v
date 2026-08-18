import { groupBy } from 'lodash-es';

export const fileLineCodequality = (file, line, codequalityData) => {
  const fileDiff = codequalityData?.files?.[file] || [];
  const lineDiff = fileDiff.filter((violation) => violation.line === line);
  return lineDiff;
};

const mapSastFinding = (finding) => ({
  line: parseInt(finding.location.startLine, 10),
  description: finding.description,
  details: finding.details,
  severity: finding.severity.toLowerCase(),
  location: finding.location,
  foundByPipelineIid: finding.foundByPipelineIid,
  identifiers: finding.identifiers,
  state: finding.state.toLowerCase(),
  title: finding.title,
});

export const fileLineSast = (file, line, sastData) =>
  (sastData?.added || [])
    .filter(
      (finding) =>
        finding.location.file === file && parseInt(finding.location.startLine, 10) === line,
    )
    .map(mapSastFinding);

export const groupSastFindingsByLine = (file, sastData) => {
  const findings = (sastData?.added || [])
    .filter((finding) => finding.location.file === file)
    .map(mapSastFinding);
  return groupBy(findings, 'line');
};
