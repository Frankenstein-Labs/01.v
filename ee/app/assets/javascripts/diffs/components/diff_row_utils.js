import { mapParallel as CEMapParallel } from '~/diffs/components/diff_row_utils';
import { fileLineCodequality, fileLineSast } from './inline_findings_utils';

export const mapParallel =
  ({
    diffFile,
    codequalityData,
    sastData,
    hasParallelDraftLeft,
    hasParallelDraftRight,
    draftsForLine,
  }) =>
  (line) => {
    let { left, right } = line;

    if (left) {
      left = {
        ...left,
        codequality: fileLineCodequality(diffFile.file_path, left.new_line, codequalityData),
        sast: fileLineSast(diffFile.file_path, left.new_line, sastData),
      };
    }
    if (right) {
      right = {
        ...right,
        codequality: fileLineCodequality(diffFile.file_path, right.new_line, codequalityData),
        sast: fileLineSast(diffFile.file_path, right.new_line, sastData),
      };
    }

    return {
      ...CEMapParallel({ diffFile, hasParallelDraftLeft, hasParallelDraftRight, draftsForLine })({
        ...line,
        left,
        right,
      }),
    };
  };
