import 'package:flutter_test/flutter_test.dart';
import 'package:hivenet/transfer_experience.dart';

void main() {
  test('a failed replica selection does not mark later stages successful', () {
    const experience = UploadExperience(
      stage: TransferStage.failed,
      message: 'Upload blocked',
      failedStage: TransferStage.selecting,
      eligibleStoragePeers: 1,
    );

    expect(
      experience.stateFor(TransferStage.selected),
      UploadStageState.completed,
    );
    expect(
      experience.stateFor(TransferStage.discovering),
      UploadStageState.completed,
    );
    expect(
      experience.stateFor(TransferStage.selecting),
      UploadStageState.failed,
    );
    expect(
      experience.stateFor(TransferStage.sending),
      UploadStageState.skipped,
    );
    expect(
      experience.stateFor(TransferStage.verifying),
      UploadStageState.skipped,
    );
  });

  test('only a completed upload marks every operational stage complete', () {
    const experience = UploadExperience(
      stage: TransferStage.complete,
      message: 'Verified',
    );

    for (final stage in TransferStage.values.take(8)) {
      expect(experience.stateFor(stage), UploadStageState.completed);
    }
  });

  test('a rejected acknowledgement fails sending and skips verification', () {
    const experience = UploadExperience(
      stage: TransferStage.failed,
      message: 'Peer acknowledgement was rejected',
      failedStage: TransferStage.sending,
    );

    expect(
      experience.stateFor(TransferStage.selecting),
      UploadStageState.completed,
    );
    expect(experience.stateFor(TransferStage.sending), UploadStageState.failed);
    expect(
      experience.stateFor(TransferStage.verifying),
      UploadStageState.skipped,
    );
  });
}
