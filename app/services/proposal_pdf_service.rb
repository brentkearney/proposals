class ProposalPdfService
  attr_reader :proposal, :temp_file, :table

  def initialize(proposal_id, file, input)
    @proposal = Proposal.find(proposal_id)
    @temp_file = file
    @input = input
  end

  def generate_latex_file
    @input = @input.presence || 'Please enter some text.'
    @input = all_proposal_fields if @input == 'all'

    LatexToPdf.config[:arguments].delete('-halt-on-error') if @proposal.is_submission

    File.open("#{Rails.root}/tmp/#{temp_file}", "w:UTF-8") do |io|
      io.write(@input)
    end
  end

  def single_booklet(table)
    @table = table
    input = all_proposal_fields if @input == 'all'

    LatexToPdf.config[:arguments].delete('-halt-on-error') if @proposal.is_submission

    File.open("#{Rails.root}/tmp/#{temp_file}", "w:UTF-8") do |io|
      io.write(input)
    end
  end

  def multiple_booklet(table, proposals)
    @table = table
    @proposals = proposals
    input = multiple_proposals_fields if @input == 'all'

    LatexToPdf.config[:arguments].delete('-halt-on-error') if @proposal.is_submission

    File.open("#{Rails.root}/tmp/#{temp_file}", "w:UTF-8") do |io|
      io.write(input)
    end
    self
  end

  def to_s
    generate_latex_file unless File.exist?("#{Rails.root}/tmp/#{@temp_file}")

    latex_infile = File.read("#{Rails.root}/tmp/#{@temp_file}")
    "#{@proposal.macros}\n\n\\begin{document}\n\n#{latex_infile}\n"
  end

  def self.format_errors(error)
    error_object = error.cause # RailsLatex::ProcessingError
    error_summary = error_object.log.lines.last(20).join("\n")

    error_output = "<h2 class=\"text-danger\">LaTeX Error Log:</h2>\n\n"
    error_output << "<h4>Last 20 lines:</h4>\n\n"
    error_output << "<pre>\n" + error_summary + "\n</pre>\n\n"
    error_output << %q[
      <%= link_to "Edit Proposal", edit_proposal_path(@proposal, tab: "tab-2"),
      class: 'btn btn-primary mb-4' %>]
    error_output << %q[
      <button class="btn btn-primary mb-4 latex-show-more" type="button"
                     data-bs-toggle="collapse" data-bs-target="#latex-error"
                     aria-expanded="false" aria-controls="latex-error">
              Show full error log
      </button>']
    error_output << "<pre class=\"collapse\" id=\"latex-error\">\n"
    error_output << "#{error_object.log}\n</pre>\n\n"

    error_output << "<h2 class=\"text-danger p-4\">LaTeX Source File:</h2>\n\n"
    error_output << "<pre id=\"latex-source\">\n"

    line_num = 1
    error_object.src.each_line do |line|
      error_output << line_num.to_s + " #{line}"
      line_num += 1
    end
    error_output << "\n</pre>\n\n"
  end

  private

  def all_proposal_fields
    return 'Proposal data not found!' if proposal.blank?

    case @table
    when "toc"
      proposal_table_of_content
    when "ntoc"
      proposal_without_content
    else
      proposal_details
    end
    @text
  end

  def multiple_proposals_fields
    case @table
    when "toc"
      proposals_with_content
    when "ntoc"
      proposals_without_content
    end
    @text
  end

  def proposals_with_content
    @text = "\\tableofcontents"
    number = 0
    @proposals.split(',').each do |id|
      number += 1
      proposal = Proposal.find_by(id: id)
      @proposal = proposal
      @text << "\\addtocontents{toc}{\ #{number}. #{proposal.subject&.title}}"
      code = proposal.code.blank? ? '' : "#{proposal&.code}: "
      @text << "\\addcontentsline{toc}{section}{ #{code} #{LatexToPdf.escape_latex(proposal&.title)}}"
      proposals_without_content
    end
    @text
  end

  def proposals_without_content
    if @table == "toc"
      code = proposal.code.blank? ? '' : "#{proposal&.code}: "
      @text << "\\section*{\\centering #{code} #{LatexToPdf.escape_latex(proposal&.title)}}"
      proposals_sections
    else
      @text = "\\section*{\\centering #{code} #{LatexToPdf.escape_latex(proposal&.title)}}"
      @proposals.split(',').each do |id|
        proposal = Proposal.find_by(id: id)
        @proposal = proposal
        code = proposal.code.blank? ? '' : "#{@proposal&.code}: "
        @text << "\\section*{\\centering #{code} #{LatexToPdf.escape_latex(proposal&.title)}}"
        proposals_sections
      end
    end
    @text
  end

  def proposals_sections
    @text << "\\subsection*{#{proposal.proposal_type&.name} }\n\n"
    @text << "#{proposal.invites.count} confirmed / #{proposal.proposal_type&.participant} maximum participants\n\n"

    @text << "\\subsection*{Lead Organizer}\n\n"
    @text << "#{proposal.lead_organizer&.fullname}  \\\\ \n\n"
    @text << "\\noindent #{proposal.lead_organizer&.email}\n\n"
    proposal_organizers
    proposal_locations
    proposal_subjects
    proposal_bibliography
    user_defined_fields
    proposal_participants
  end

  def proposal_table_of_content
    @text = "\\tableofcontents"
    @text << "\\addtocontents{toc}{\ 1. #{proposal.subject&.title}}"
    code = proposal.code.blank? ? '' : "#{proposal&.code}: "
    @text << "\\addcontentsline{toc}{section}{ #{code} #{LatexToPdf.escape_latex(proposal&.title)}}"
    proposal_without_content
    @text
  end

  def proposal_without_content
    code = proposal.code.blank? ? '' : "#{proposal&.code}: "
    if @table == "toc"
      @text << "\\section*{\\centering #{code} #{LatexToPdf.escape_latex(proposal&.title)}}"
    else
      @text = "\\section*{\\centering #{code} #{LatexToPdf.escape_latex(proposal&.title)}}"
    end
    @text << "\\subsection*{#{proposal.proposal_type&.name} }\n\n"
    @text << "#{proposal.invites.count} confirmed / #{proposal.proposal_type&.participant} maximum participants\n\n"

    @text << "\\subsection*{Lead Organizer}\n\n"
    @text << "#{proposal.lead_organizer&.fullname}  \\\\ \n\n"
    @text << "\\noindent #{proposal.lead_organizer&.email}\n\n"
    proposal_organizers
    proposal_locations
    proposal_subjects
    user_defined_fields
    proposal_bibliography unless proposal.no_latex
    proposal_participants
    @text
  end

  def proposal_details
    code = proposal.code.blank? ? '' : "#{proposal.code}: "
    confirmed_participants = proposal.invites.where(status: "confirmed", invited_as: "Participant")
    confirmed_organizers = proposal.invites.where(status: "confirmed", invited_as: "Organizer")
    @text = "\\section*{\\centering #{code} #{LatexToPdf.escape_latex(proposal.title)} }\n\n"
    @text << "\\subsection*{#{proposal.proposal_type&.name} }\n\n"
    @text << "\\noindent #{confirmed_participants.count} confirmed / #{proposal.proposal_type&.participant} maximum participants\n\n"
    @text << "\\noindent #{confirmed_organizers.count} confirmed / #{proposal.proposal_type&.co_organizer} maximum organizers\n\n"
    @text << "\\noindent 1 confirmed / lead organizer\n\n"

    @text << "\\subsection*{Lead Organizer}\n\n"

    @text << "#{proposal.lead_organizer&.fullname} (#{LatexToPdf.escape_latex(proposal.lead_organizer&.affiliation)}) \\\\ \n\n"

    @text << "\\noindent #{proposal.lead_organizer&.email}\n\n"
    proposal_organizers
    proposal_locations
    proposal_subjects
    proposal_bibliography
    user_defined_fields
    proposal_participants
  end

  def proposal_organizers
    return if proposal.supporting_organizers&.count&.zero?

    @text << "\\subsection*{Supporting Organizers}\n\n"
    proposal.supporting_organizers.each do |organizer|
      @text << "\\noindent #{organizer&.person&.firstname} #{organizer&.person&.lastname} (#{LatexToPdf.escape_latex(organizer&.person&.affiliation)})\n\n"
    end
  end

  def proposal_locations
    locations = proposal.locations&.count > 1 ? 'Locations' : 'Location'
    unless proposal.locations.empty?
      @text << "\\subsection*{Preferred #{locations}}\n\n"
      @text << "\\begin{enumerate}\n"
      proposal.locations&.each do |location|
        @text << "\\item #{location.name}\n"
      end
      @text << "\\end{enumerate}\n"
    end
  end

  def proposal_subjects
    @text << "\\subsection*{Subject Areas}\n\n"
    @text << "#{proposal.subject&.title} \\\\ \n" if proposal.subject.present?

    ams_subject1 = proposal.ams_subjects&.where(code: 'code1').first&.title
    @text << "\\noindent #{ams_subject1} \\\\ \n" if ams_subject1.present?

    ams_subject2 = proposal.ams_subjects&.where(code: 'code2').first&.title
    @text << "\\noindent #{ams_subject2} \\\\ \n" if ams_subject2.present?
  end

  def proposal_bibliography
    return unless proposal.bibliography.present?
    
    @text << "\\subsection*{Bibliography}\n\n"
    @text << "\\noindent #{LatexToPdf.escape_latex(proposal&.bibliography)}\n\n"
  end

  def user_defined_fields
    proposal.answers&.each do |field|
      if field.proposal_field&.fieldable_type == "ProposalFields::PreferredImpossibleDate"
        preferred_impossible_dates(field)
        next
      end
      question = field.proposal_field.statement
      @text << "\\subsection*{#{LatexToPdf.escape_latex(question)}}\n\n" if question.present?
      if field.answer.present?

        @text << if @proposal.no_latex
                   "\\noindent #{LatexToPdf.escape_latex(field.answer)}\n\n"
                 else
                   "\\noindent #{field.answer}\n\n"
                 end
      end
    end
  end

  def proposal_participants
    return if proposal.participants&.count&.zero?

    @careers = Person.where(id: @proposal.participants.pluck(:person_id)).pluck(:academic_status)
    @text << "\\section*{Participants}\n\n"
    @careers.uniq.each do |career|
      @text << "\\noindent #{career}\n\n"
      @participants = proposal.participants_career(career)
      @text << "\\begin{enumerate}\n\n"
      @participants.each do |participant|
        @text << "\\item #{participant.firstname} #{participant.lastname} (#{LatexToPdf.escape_latex(participant.affiliation)}) \\ \n"
      end
      @text << "\\end{enumerate}\n\n"
    end
  end

  def preferred_impossible_dates(field)
    return unless field&.answer

    # @text << "\\subsection*{#{field.proposal_field.statement}}\n\n"
    preferred = JSON.parse(field.answer)&.first(5)
    unless preferred.any?
      @text << "\\subsection*{Preferred dates}\n\n"
      @text << "\\begin{enumerate}\n\n"
      preferred.each do |date|
        @text << "\\item #{date}\n"
      end
      @text << "\\end{enumerate}\n\n"
    end

    impossible = JSON.parse(field.answer)&.last(2)
    unless impossible.any?
      @text << "\\subsection*{Impossible dates}\n\n"
      @text << "\\begin{enumerate}\n\n"
      impossible.each do |date|
        @text << "\\item #{date}\n\n"
      end
      @text << "\\end{enumerate}\n\n"
    end
  end
end
