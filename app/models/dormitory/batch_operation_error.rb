module Dormitory
  class BatchOperationError < ApplicationRecord
    # PURPOSE: Records per-resident errors during batch eviction operations
    # SPECIFICATION: SPEC-DORM-05
    belongs_to :batch_operation, class_name: "Dormitory::BatchOperation"
    belongs_to :resident, class_name: "Dormitory::Resident", optional: true
    belongs_to :accommodation, class_name: "Dormitory::Accommodation", optional: true
  end
end
