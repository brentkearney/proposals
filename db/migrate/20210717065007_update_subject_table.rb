class UpdateSubjectTable < ActiveRecord::Migration[6.1]
  def change
    Subject.find_by(code: "ARNT")&.update(code: "ARGEO", title: "Arithmetic Geometry")
    subject_category = SubjectCategory.first
    Subject.create(code: "ANNT", title: "Analytic Number Theory", subject_category: subject_category)
    Subject.create(code: "ALNT", title: "Algebraic Number Theory", subject_category: subject_category)
  end
end
