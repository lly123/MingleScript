require "rexml/document"
require "open-uri"
require "net/http"
require "mingleAPIHelper"

class Overview
  include MingleAPIHelper
  
  attr_accessor :sprint_order
  attr_accessor :sprint_start_date
  attr_accessor :sprint_end_date
  attr_accessor :release_name

  TemplateNames = ['Display_Team_Sprint_Overview', 'Data1_Team_Sprint_Overview',
                  'Data2_Team_Sprint_Overview', 'Performance_Team_Sprint_Overview',
                  'Workflow_DM_Team_Sprint_Overview', 'Workflow_WL_Team_Sprint_Overview',
                  'Environment_CI_Team_Sprint_Overview']

  MaxWellURI = '/api/v2/projects/maxwell'
  MaxWellWikiURI = "#{MaxWellURI}/wiki.xml"
  
  def generateOverviews
    generateOverviewsAccordingToTemplates
    updateOverviewList
  end

  def generateOverviewsAccordingToTemplates

    def replaceTagsWithValues(content, tagsAndValues)
      tagsAndValues.to_a.inject(content) { |content, tagAndValue| content.gsub(tagAndValue[0], tagAndValue[1]) }
    end

    def wikiPageName(prefix, sprint)
      prefix + ' - ' + sprint
    end

    scriptTemplatesURI = "/api/v2/projects/mingle_script_templates"

    current_sprint_order = %r{\(Current Sprint Order\)}i
    current_sprint = %r{\(Current Sprint\)}i
    current_sprint_start_date = %r{\(Current Sprint Start Date\)}i
    current_sprint_end_date = %r{\(Current Sprint End Date\)}i
    current_release = %r{\(Current Release\)}i 

    tagsAndValues = {
        current_sprint_order => "#{sprint_order}",
        current_sprint => "\'Sprint #{sprint_order}\'",
        current_sprint_start_date => "\'#{sprint_start_date}\'",
        current_sprint_end_date => "\'#{sprint_end_date}\'",
        current_release => "\'#{release_name}\'"
    }

    TemplateNames.each do |templateName|
      text = askMingle("#{scriptTemplatesURI}/wiki/#{templateName}.xml", %q{//page/content}).first
      wiki_page_name = wikiPageName(templateName, tagsAndValues[current_sprint][1..-2])
      wiki_page_content = replaceTagsWithValues(text, tagsAndValues)
      templateURI = "#{MaxWellURI}/wiki/#{wiki_page_name.gsub(/\s/,'_')}.xml"

      response = get_response(templateURI)
      if response.code == "404"
        create MaxWellWikiURI, {'page[name]' => wiki_page_name,'page[content]' => wiki_page_content}
      else 
        if response.code == "200"
          update templateURI, "page[content]=#{wiki_page_content}"
        else
          raise "response code #{response.code}"
        end
      end
    end
  end

  def updateOverviewList

    def findHowManySprintOverviewsAlreadyInTheProject
      askMingle(MaxWellWikiURI, %q{//page[contains(name, ' - Sprint')]/name}).inject([]) { |numbers, text|
        numbers << text[/\s-\sSprint\s([0-9]+)$/, 1]
      }.uniq
    end

    def generateContentOfSprintOverviewList(teamName, sprintNumbers)
      header = <<-HEADER
        {% dashboard-panel %}
        {% panel-heading %}#{teamName} Sprint Overview{% panel-heading %}
        {% panel-content %}
      HEADER

      footer = <<-FOOTER
        {% panel-content %}
        {% dashboard-panel %}
      FOOTER

      sprintNumbers.collect{|s| s.to_i}.sort{|a,b| b<=>a}.inject(header) { |content, number|
        content << "[[#{teamName} Sprint Overview - Sprint #{number}]]<br/>\n"
      } << footer
    end

    def getTeamName(templateName)
      templateName[/(\w+)_Sprint_Overview/, 1].gsub(/_/, ' ')
    end

    def updateOverview(templateName, content)
      update("#{MaxWellURI}/wiki/#{templateName}.xml", "page[content]=#{content}")
    end

    TemplateNames.each do |templateName|
      sprintNumbers = findHowManySprintOverviewsAlreadyInTheProject
      overviewContent = generateContentOfSprintOverviewList(getTeamName(templateName), sprintNumbers)
      updateOverview(templateName, overviewContent)
    end
  end
end
