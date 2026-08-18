import {
  getFormattedSummary,
  limitVulnerabilityGradeProjects,
  PdfExportError,
} from 'ee/security_dashboard/helpers';

describe('getFormattedSummary', () => {
  it('returns a properly formatted array given a valid, non-empty summary', () => {
    const summary = {
      dast: { vulnerabilitiesCount: 0 },
      containerScanning: { vulnerabilitiesCount: 1 },
      dependencyScanning: { vulnerabilitiesCount: 2 },
    };

    expect(getFormattedSummary(summary)).toEqual([
      ['DAST', summary.dast],
      ['Container Scanning', summary.containerScanning],
      ['Dependency Scanning', summary.dependencyScanning],
    ]);
  });

  it('filters empty reports out', () => {
    const summary = {
      dast: { vulnerabilitiesCount: 0 },
      containerScanning: null,
      dependencyScanning: {},
    };

    expect(getFormattedSummary(summary)).toEqual([['DAST', summary.dast]]);
  });

  it('filters invalid report types out', () => {
    const summary = {
      dast: { vulnerabilitiesCount: 0 },
      invalidReportType: { vulnerabilitiesCount: 1 },
    };

    expect(getFormattedSummary(summary)).toEqual([['DAST', summary.dast]]);
  });

  it.each([undefined, [], [1], 'hello world', 123])(
    'returns an empty array when summary is %s',
    (summary) => {
      expect(getFormattedSummary(summary)).toEqual([]);
    },
  );
});

describe('limitVulnerabilityGradeProjects', () => {
  const createMockGrade = ({ grade, count, numberOfProjects }) => ({
    grade,
    count,
    projects: {
      nodes: Array.from({ length: numberOfProjects }, (_, i) => ({
        id: `project-${i + 1}`,
        name: `Project ${i + 1}`,
      })),
    },
  });

  const gradeWithManyProjects = createMockGrade({ grade: 'F', count: 6, numberOfProjects: 7 });
  const gradeWithFewProjects = createMockGrade({ grade: 'A', count: 2, numberOfProjects: 2 });
  const gradeWithNoProjects = createMockGrade({ grade: 'B', count: 0, numberOfProjects: 0 });
  const defaultMaxProjects = 5;

  describe(`default behavior (maxProjects = ${defaultMaxProjects})`, () => {
    it.each`
      description                                                              | input                      | expectedLength
      ${`should limit projects to ${defaultMaxProjects} when exceeding limit`} | ${[gradeWithManyProjects]} | ${defaultMaxProjects}
      ${'should return grade unchanged when it has fewer projects'}            | ${[gradeWithFewProjects]}  | ${2}
      ${'should handle empty projects array'}                                  | ${[gradeWithNoProjects]}   | ${0}
    `('$description', ({ input, expectedLength }) => {
      const result = limitVulnerabilityGradeProjects(input);

      expect(result).toHaveLength(1);
      expect(result[0].projects.nodes).toHaveLength(expectedLength);
    });
  });

  describe('custom maxProjects parameter', () => {
    it.each`
      description                              | input                      | maxProjects | expectedLength
      ${'should respect custom maxProjects=3'} | ${[gradeWithManyProjects]} | ${3}        | ${3}
      ${'should respect custom maxProjects=1'} | ${[gradeWithManyProjects]} | ${1}        | ${1}
    `('$description', ({ input, maxProjects, expectedLength }) => {
      const result = limitVulnerabilityGradeProjects(input, maxProjects);

      expect(result).toHaveLength(1);
      expect(result[0].projects.nodes).toHaveLength(expectedLength);
    });
  });

  describe('edge cases', () => {
    it('should handle empty input array', () => {
      const result = limitVulnerabilityGradeProjects([]);

      expect(result).toEqual([]);
    });

    it('should handle grade with null projects', () => {
      const gradeWithNullProjects = { grade: 'C', count: 0, projects: null };
      const result = limitVulnerabilityGradeProjects([gradeWithNullProjects]);

      expect(result[0]).toBe(gradeWithNullProjects);
    });

    it('should handle grade with undefined projects', () => {
      const gradeWithUndefinedProjects = { grade: 'D', count: 0 };
      const result = limitVulnerabilityGradeProjects([gradeWithUndefinedProjects]);

      expect(result[0]).toBe(gradeWithUndefinedProjects);
    });
  });
});

describe('PdfExportError', () => {
  it('creates a proper custom error', () => {
    const message = 'Charts are still loading. Please wait and try again.';
    const error = new PdfExportError(message);

    expect(error).toBeInstanceOf(PdfExportError);
    expect(error.message).toBe(message);
    expect(error.name).toBe('PdfExportError');
  });
});
