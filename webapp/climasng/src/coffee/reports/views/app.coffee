
# $ = require 'jquery'
# _ = require 'lodash'
# Backbone = require 'backbone'
# L = require 'leaflet'

# MapLayer = require '../models/maplayer'

require '../util/shims' # help IE to get up to date

# disable the jshint warning about "did you mean to return a
# conditional" which crops up all the time in coffeescript compiled
# code.
### jshint -W093 ###

# disable the jshint warning about "use !== to compare with null"
# which coffeescript compiled code sometimes triggers.
### jshint -W041 ###

# -------------------------------------------------------------------
debug = (itemToLog, itemLevel)->
    levels = ['verydebug', 'debug', 'message', 'warning']

    # threshold = 'verydebug'
    # threshold = 'debug'
    threshold = 'message'

    itemLevel = 'debug' unless itemLevel

    thresholdNum = levels.indexOf threshold
    messageNum = levels.indexOf itemLevel
    return if thresholdNum > messageNum

    if itemToLog + '' == itemToLog
        # it's a string..
        console.log "[#{itemLevel}] #{itemToLog}"
    else
        console.log itemToLog
# -------------------------------------------------------------------
# -------------------------------------------------------------------

AppView = Backbone.View.extend {
    # ---------------------------------------------------------------
    # this view's base element
    tagName: 'form'
    className: ''
    id: 'reportform'
    # ---------------------------------------------------------------
    # some settings
    dataUrl: "#{location.protocol}//#{location.host}/data"
    rasterApiUrl: "#{location.protocol}//localhost:10600/api/raster/1/wms_data_url"
    # ---------------------------------------------------------------
    # tracking the splitter bar
    trackSplitter: false
    trackPeriod: 100
    # ---------------------------------------------------------------
    events:
        'change .sectionselector input': 'updateSectionSelection'
        'change .regionselect input': 'updateRegionSelection'
        'change .regionselect select': 'updateRegionSelection'
        'change .yearselect input': 'updateYearSelection'
        'click .getreport': 'getReport'
    # ---------------------------------------------------------------
    initialize: ()->
        debug 'AppView.initialize'

        # more annoying version of bindAll requires this concat stuff
        _.bindAll.apply _, [this].concat _.functions(this)

        # kick off the fetching of stuff
        @fetchReportSections()
        @fetchRegions()
        @fetchYears()

        @updateSummary()

        @hash = '' # current hash, assume blank
        @checkUrl()
        # @tick()
    # ---------------------------------------------------------------
    render: ()->
        debug 'AppView.render'

        @$el.append AppView.templates.layout {}
        $('#contentwrap .maincontent').append @$el

    # ---------------------------------------------------------------
    # check / update the hash part of the URL and match form fields
    # ---------------------------------------------------------------
    checkUrl: ()->
        hash = window.location.hash
        return if @hash is hash

    # ---------------------------------------------------------------
    # actually go get the report
    # ---------------------------------------------------------------
    getReport: ()->
        debug 'AppView.getReport'

        # remove any previous form
        @$('#reportform').remove()

        form = []
        form.push '<form action="/regionreport" method="get" id="reportform">'

        # selected year
        form.push '<input type="hidden" name="year" value="' + @selectedYear + '">'

        # selected region
        form.push '<input type="hidden" name="regiontype" value="' + @selectedRegionType + '">'
        form.push '<input type="hidden" name="region" value="' + @selectedRegion + '">'

        # selected report sections
        form.push '<input type="hidden" name="sections" value="' + @selectedSections.join(' ') + '">'

        form.push '</form>'

        @$el.append form.join '\n'
        @$('#reportform').submit()

    # ---------------------------------------------------------------
    # deal with report sections
    # ---------------------------------------------------------------
    fetchReportSections: ()->
        debug 'AppView.fetchReportSections'

        fetch = $.ajax @dataUrl + '/reportsections'

        # later this will be an ajax call, for now make a deferred object
        # fetch = $.Deferred()

        fetch.done (data)=>
            @possibleSections = data.sections
            sectionselect = @$ '.sectionselect'
            sectionselect.empty().removeClass 'loading'
            @buildReportSectionList @possibleSections, sectionselect

        # # pretend it took a while to get the data..
        # setTimeout ()->
        #     fetch.resolve({
        #         sections: [
        #             {
        #                 id: 'intro'
        #                 name: 'Introduction'
        #                 description: 'title, credits, and introductory paragraphs.'
        #                 presence: 'required'
        #                 sections: []
        #             },{
        #                 id: 'climatereview'
        #                 name: 'Climate Review'
        #                 description: 'a description of the region\'s current and projected climate.'
        #                 presence: 'optional'
        #                 sections: [
        #                     {
        #                         id: 'temperature'
        #                         name: 'Temperature'
        #                         description: 'current and projected temperature.'
        #                         presence: 'optional'
        #                         sections: []
        #                     },{
        #                         id: 'rainfall'
        #                         name: 'Rainfall'
        #                         description: 'current and projected precipitation.'
        #                         presence: 'optional'
        #                         sections: []
        #                     }
        #                 ]
        #             },{
        #                 // ...
        #             }
        #         ]
        #     })
        # , 500 + (500 * Math.random())

        # now return a promise in case we need to wait for this
        return fetch.promise()
    # ---------------------------------------------------------------
    buildReportSectionList: (data, wrapper)->
        debug 'AppView.buildReportSectionList'

        $.each data, (index, item)=>

            # make a row for this item
            selectorRow = $ AppView.templates.sectionSelector(item)
            $(wrapper).append selectorRow

            # if the item has subitems, insert those
            if item.sections.length > 0
                subsections = $ AppView.templates.subsections()
                @buildReportSectionList item.sections, subsections
                $(selectorRow).addClass('hassubsections').append(subsections)

        @updateSummary()
    # ---------------------------------------------------------------
    updateSectionSelection: (event)->
        debug 'AppView.updateSectionSelection'

        @handleSectionSelection @possibleSections
    # ---------------------------------------------------------------
    handleSectionSelection: (sectionList, parent)->
        debug 'AppView.handleSectionSelection'

        $.each sectionList, (index, item)=>
            # find the selection checkbox..
            selector = @$ "#section-#{ item.id.replace /\./g, '\\.' }"
            selectionControl = selector.find 'input'

            # set the right class on the selector
            if selectionControl.prop 'checked'
                selector.removeClass 'unselected'
            else
                selector.addClass 'unselected'

            if item.sections?.length > 0
                @handleSectionSelection item.sections, item.id

        @updateSummary()
    # ---------------------------------------------------------------
    # deal with regions
    # ---------------------------------------------------------------
    fetchRegions: ()->
        debug 'AppView.fetchRegions'

        fetch = $.ajax @dataUrl + '/reportregions'
        fetch.done (data)=>
            @buildRegionList data

        # # pretend it took a while to get the data..
        # setTimeout ()->
        #     fetch.resolve({
        #         regiontypes: [
        #             {
        #                 id: 'nrm'
        #                 name: 'NRM region'
        #                 regions: [
        #                     { id: 'NRM_ACT', name: 'ACT' },
        #                     { id: 'NRM_Adelaide_and_Mount_Lofty_Ranges', name: 'Adelaide and Mount Lofty Ranges' },
        #                     { id: 'NRM_Alinytjara_Wilurara', name: 'Alinytjara Wilurara' },
        #                     { id: 'NRM_Avon', name: 'Avon' },
        #                     { id: 'NRM_Border_Rivers-Gwydir', name: 'Border Rivers-Gwydir' },
        #                     // ...
        #                     { id: 'NRM_Wimmera', name: 'Wimmera' }
        #                 ]
        #             },{
        #                 id: 'ibra'
        #                 name: 'IBRA bioregion'
        #                 regions: []
        #             }
        #         ]
        #     })
        # , 500 + (500 * Math.random())

        # now return a promise in case we need to wait for this
        return fetch.promise()
    # ---------------------------------------------------------------
    buildRegionList: (data)->
        debug 'AppView.buildRegionList'

        @regions = data.regiontypes
        regionselect = @$ '.regionselect'
        regionselect.empty().removeClass 'loading'

        $.each @regions, (index, regionType)=>
            # make a row for this regiontype

            # first the regions go into a select box
            regionType.optionList = [
                AppView.templates.regionSelector(reg) for reg in regionType.regions
            ].join "\n"

            regionTypeRow = $ AppView.templates.regionTypeSelector(regionType)
            regionselect.append regionTypeRow

        @updateSummary()
    # ---------------------------------------------------------------
    updateRegionSelection: (event)->
        debug 'AppView.updateRegionSelection'

        selectedType = @$('[name=regiontype]:checked').val()

        $.each @regions, (index, regionType)=>
            # find the selection checkbox..
            selector = @$ "#regiontype-#{ regionType.id }"

            # set the right class on the selector
            if selectedType == regionType.id
                selector.addClass 'typeselected'
                @selectedRegionType = regionType.id
                @selectedRegion = $(selector.find('select')).val()
                if @selectedRegion == ''
                    selector.removeClass 'regionselected'
                else
                    selector.addClass 'regionselected'
                    # note the region data for later..
                    @selectedRegionInfo = _.find regionType.regions, (region)=> region.id == @selectedRegion
            else
                selector.removeClass 'typeselected'

        @updateSummary()
    # ---------------------------------------------------------------
    # deal with years
    # ---------------------------------------------------------------
    fetchYears: ()->
        debug 'AppView.fetchYears'

        # later this will be an ajax call, for now make a deferred object
        fetch = $.Deferred()

        fetch.done (data)=>
            @buildYearList data

        # pretend it took a second to get the data..
        setTimeout ()->
            fetch.resolve({
                years: [
                    '2015'
                    '2025'
                    '2035'
                    '2045'
                    '2055'
                    '2065'
                    '2075'
                    '2085'
                ]
            })
        , 500 + (500 * Math.random())

        # now return a promise in case we need to wait for this
        return fetch.promise()
    # ---------------------------------------------------------------
    buildYearList: (data)->
        debug 'AppView.buildYearList'

        @years = data.years
        yearselect = @$ '.yearselect'
        yearselect.empty().removeClass 'loading'

        $.each @years, (index, year)=>
            # make a selector for this year
            yearselect.append AppView.templates.yearSelector({ year: year })

        @updateSummary()
    # ---------------------------------------------------------------
    updateYearSelection: (event)->
        debug 'AppView.updateYearSelection'

        @selectedYear = @$('[name=yearselector]:checked').val()

        $.each @years, (index, year)=>
            # find the selection checkbox..
            selector = @$ "#year-#{ year }"

            # set the right class on the selector
            if @selectedYear == year
                selector.addClass 'yearselected'
            else
                selector.removeClass 'yearselected'

        @updateSummary()
    # ---------------------------------------------------------------
    # update report summary
    # ---------------------------------------------------------------
    sectionId: (sectionDom)->
        # debug 'AppView.sectionId'

        $(sectionDom).find('input').attr 'value'
    # ---------------------------------------------------------------
    sectionName: (sectionDom)->
        # debug 'AppView.sectionName'

        @sectionInfo(sectionDom).name
    # ---------------------------------------------------------------
    sectionInfo: (sectionDom)->
        debug 'AppView.sectionInfo'

        # get a list of this section's parent ids
        parentage = $(sectionDom).parents '.sectionselector'
        parentIds = parentage.map( (i, elem)=>
            @sectionId elem
        ).get().reverse()

        # add this section's own id
        parentIds.push @sectionId(sectionDom)

        # while we're here, add this to the selected sections list
        @selectedSections.push @sectionId(sectionDom)

        # now walk into the sections hierarchy
        info = { sections: @possibleSections }

        parentIds.forEach (id)->
            info = _.filter(info.sections, (section)-> section.id == id)[0]

        # finally we have a pointer to the info for this section
        return info
    # ---------------------------------------------------------------
    subSectionList: (sectionDom)->
        debug 'AppView.sectionList'

        list = []
        subsections = $(sectionDom).children('.subsections')
        subsections.children('.sectionselector').not('.unselected').each (i, elem)=>
            name = @sectionName(elem)
            subs = @subSectionList(elem)
            if subs isnt ''
                name = name + ' (' + subs + ')'
            list.push name

        return list.join ', '

    # ---------------------------------------------------------------
    updateSummary: ()->
        debug 'AppView.updateSummary'

        selectedSections = @$('.sectionselect > .sectionselector').not('.unselected')

        @selectedSections = []
        contentList = []
        selectedSections.each (index, section)=>
            info = @sectionName section
            subList = @subSectionList section
            if subList isnt ''
                info = info + ': ' + subList.toLowerCase()
            contentList.push info + '.'

        content = ''
        if contentList.length > 0
            content = '<li>' + contentList.join('</li><li>') + '</li>'

        summary = {
            regionName: @selectedRegionInfo?.name
            year: @selectedYear
            content: content
        }

        @$('.reviewblock').html AppView.templates.reviewBlock(summary)
        @$('.reviewblock').toggleClass 'regionselected', (@selectedRegionInfo isnt undefined)
        @$('.reviewblock').toggleClass 'yearselected', (@selectedYear isnt undefined)
    # ---------------------------------------------------------------
},{ templates: { # ==================================================
    # templates here
    # ---------------------------------------------------------------
    layout: _.template """
        <div class="reviewblock"></div>
        <div class="formblock">
            <h1>Report on</h1>
            <div class="loading select regionselect">loading available regions..</div>

            <h1>In the year</h1>
            <div class="loading select yearselect">loading available years..</div>

            <h1>Including</h1>
            <div class="loading select sectionselect">loading available sections..</div>
        </div>
    """
    # ---------------------------------------------------------------
    reviewBlock: _.template """
        <h1>Selected Report</h1>
        <p class="coverage">Covers
            <% if (regionName) { %><%= regionName %><% } else { %><em>(unspecified region)</em><% } %>
            in
            <% if (year) { %><%= year %>.<% } else { %><em>(unspecified year)</em>.<% } %>
        </p>
        <ul class="contents"><%= content %></ul>
        <button type="button" class="getreport">download report</button>
    """
    # ---------------------------------------------------------------
    reviewContentItem: _.template """
        <li>item</li>
    """
    # ---------------------------------------------------------------
    regionTypeSelector: _.template """
        <div class="regiontypeselector" id="regiontype-<%= id %>">
            <label class="name"><input
                class="regiontype"
                name="regiontype"
                type="radio"
                value="<%= id %>"
            /> <%= name %>
            </label>
            <div class="regionselectorwrapper"><select class="regionselector">
                <option value="" disabled="disabled" selected="selected">select a region&hellip;</option>
                <%= optionList %>
            </select></div>
        </div>
    """
    # ---------------------------------------------------------------
    regionSelector: _.template """<option value="<%= id %>"><%= name %></option>"""
    # ---------------------------------------------------------------
    yearSelector: _.template """
        <div class="yearrow" id="year-<%= year %>">
            <label class="name"><input
                class="yearselector"
                name="yearselector"
                type="radio"
                value="<%= year %>"
            /> <%= year %></label>
        </div>
    """
    # ---------------------------------------------------------------
    sectionSelector: _.template """
        <div class="sectionselector<% if (initial != 'included') { print(' unselected'); } %>" id="section-<%= id %>">
            <label class="name"
                <% if (presence == 'required') { print('title="This section is required"'); } %>
            ><input
                type="checkbox"
                value="<%= id %>"
                <% if (initial == 'included') { print('checked="checked"'); } %>
                <% if (presence == 'required') { print('disabled="disabled"'); } %>
            /> <%= name %></label>
            <p class="description"><%= description %></p>

        </div>
    """
    # ---------------------------------------------------------------
    subsections: _.template """
        <div class="subsections clearfix">
        </div>
    """
    # ---------------------------------------------------------------
}}

module.exports = AppView