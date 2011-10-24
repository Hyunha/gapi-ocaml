open OUnit

let test_parse_personal_settings () =
  let ch = open_in "test/data/settings.xml" in
  let settings = GdataRequest.parse_xml
                   (fun () -> input_byte ch)
                   GdataCalendar.parse_personal_settings in
  let country = Hashtbl.find settings "country" in
  let customCalMode = Hashtbl.find settings "customCalMode" in
    assert_equal ~msg:"country setting" "EH" country;
    assert_equal ~msg:"customCalMode setting" "custom,14" customCalMode

let test_parse_calendar_feed () =
  let ch = open_in "test/data/all_calendars.xml" in
  let feed = GdataRequest.parse_xml
               (fun () -> input_byte ch)
               GdataCalendar.parse_calendar_feed in
    assert_equal ~msg:"feed author"
      "Coach"
      (List.hd feed.GdataCalendar.cf_authors).GdataAtom.a_name;
    assert_equal ~msg:"feed title"
      "Coach's Calendar List"
      feed.GdataCalendar.cf_title.GdataAtom.tc_value

let test_parse_calendar_entry () =
  let ch = open_in "test/data/calendar_entry.xml" in
  let entry = GdataRequest.parse_xml
                (fun () -> input_byte ch)
                GdataCalendar.parse_calendar_entry in
    assert_equal ~msg:"entry title"
      "Little League Schedule"
      entry.GdataCalendar.ce_title.GdataAtom.tc_value;
    assert_equal ~msg:"entry timezone"
      "America/Los_Angeles"
      entry.GdataCalendar.ce_timezone

let test_parse_calendar_entry_with_extensions () =
  let ch = open_in "test/data/calendar_entry_with_extensions.xml" in
  let entry = GdataRequest.parse_xml
                (fun () -> input_byte ch)
                GdataCalendar.parse_calendar_entry in
    assert_equal
      ~printer:(fun xs ->
                  List.fold_left
                    (fun s x ->
                       s ^ (TestHelper.string_of_xml_data_model x))
                    ""
                    xs)
      [GdataCore.AnnotatedTree.Node
         ([`Element;
           `Name "new-element";
           `Namespace "http://schemas.google.com/g/2005"],
          [GdataCore.AnnotatedTree.Leaf
             ([`Attribute;
               `Name "value";
               `Namespace ""],
              GdataCore.Value.String "value");
           GdataCore.AnnotatedTree.Node
             ([`Element;
               `Name "new-child";
               `Namespace "http://schemas.google.com/g/2005"],
              [GdataCore.AnnotatedTree.Leaf
                 ([`Text],
                  GdataCore.Value.String "text")
              ])
          ])
      ]
      entry.GdataCalendar.ce_extensions

let test_calendar_entry_to_data_model () =
  let entry =
    { GdataCalendar.empty_entry with
          GdataCalendar.ce_id = "id";
          GdataCalendar.ce_kind = "kind";
          GdataCalendar.ce_authors = [
            { GdataAtom.a_lang = "en-US";
              GdataAtom.a_email = "author1@test.com";
              GdataAtom.a_name = "author1";
              GdataAtom.a_uri = "urn:uri";
            };
            { GdataAtom.empty_author with
                  GdataAtom.a_email = "author2@test.com";
                  GdataAtom.a_name = "author2";
            };
          ];
          GdataCalendar.ce_categories = [
            { GdataAtom.c_label = "label";
              GdataAtom.c_scheme = "scheme";
              GdataAtom.c_term = "term";
              GdataAtom.c_lang = "en-US";
            };
            { GdataAtom.empty_category with
                  GdataAtom.c_scheme = "scheme2";
                  GdataAtom.c_term = "term2";
            }
          ];
          GdataCalendar.ce_contributors = [
            { GdataAtom.a_lang = "en-US";
              GdataAtom.a_email = "contributor1@test.com";
              GdataAtom.a_name = "contributor1";
              GdataAtom.a_uri = "urn:uri";
            };
            { GdataAtom.empty_author with
                  GdataAtom.a_email = "contributor2@test.com";
                  GdataAtom.a_name = "contributor2";
            };
          ];
          GdataCalendar.ce_content =
            { GdataAtom.empty_content with
                  GdataAtom.tc_src = "src";
            };
          GdataCalendar.ce_published = GdataDate.of_string "2010-05-15T20:00:00.000Z";
          GdataCalendar.ce_updated = GdataDate.of_string "2011-08-16T12:00:00.000Z";
          GdataCalendar.ce_edited = GdataDate.of_string "2011-06-06T15:00:00.000Z";
          GdataCalendar.ce_accesslevel = "accesslevel";
          GdataCalendar.ce_links = [
            { GdataCalendar.empty_link with
                  GdataCalendar.cl_href = "http://href";
                  GdataCalendar.cl_rel = "self";
                  GdataCalendar.cl_type = "application/atom+xml";
            };
            { GdataCalendar.cl_href = "http://href2";
              GdataCalendar.cl_length = Int64.of_int 10;
              GdataCalendar.cl_rel = "alternate";
              GdataCalendar.cl_title = "title";
              GdataCalendar.cl_type = "application/atom+xml";
              GdataCalendar.cl_webContent =
                { GdataCalendar.wc_height = 100;
                  GdataCalendar.wc_url = "http://webcontent";
                  GdataCalendar.wc_width = 200;
                  GdataCalendar.wc_webContentGadgetPrefs = [
                    { GdataCalendar.wcgp_name = "name";
                      GdataCalendar.wcgp_value = "value";
                    };
                    { GdataCalendar.wcgp_name = "name2";
                      GdataCalendar.wcgp_value = "value2";
                    };
                  ];
                };
            };
          ];
          GdataCalendar.ce_where = [
            "where1";
            "where2";
          ];
          GdataCalendar.ce_color = "#5A6986";
          GdataCalendar.ce_hidden = true;
          GdataCalendar.ce_selected = true;
          GdataCalendar.ce_timezone = "America/Los_Angeles";
          GdataCalendar.ce_timesCleaned = 1;
          GdataCalendar.ce_summary =
            { GdataAtom.tc_src = "src";
              GdataAtom.tc_type = "type";
              GdataAtom.tc_lang = "en-US";
              GdataAtom.tc_value = "summary";
            };
          GdataCalendar.ce_title =
            { GdataAtom.empty_text with
                  GdataAtom.tc_value = "title";
            };
    } in
  let tree = GdataCalendar.calendar_entry_to_data_model entry in
    TestHelper.assert_equal_file
      "test/data/test_calendar_entry_to_data_model.xml"
      (GdataRequest.data_to_xml_string tree)

let test_parse_calendar_event_entry () =
  let ch = open_in "test/data/event_entry.xml" in
  let entry = GdataRequest.parse_xml
                (fun () -> input_byte ch)
                GdataCalendarEvent.parse_calendar_event_entry in
  let tree = GdataCalendarEvent.calendar_event_entry_to_data_model entry in
    TestHelper.assert_equal_file
      "test/data/test_parse_calendar_event_entry.xml"
      (GdataRequest.data_to_xml_string tree)

let suite = "Calendar Model test" >:::
  ["test_parse_personal_settings" >:: test_parse_personal_settings;
   "test_parse_calendar_feed" >:: test_parse_calendar_feed;
   "test_parse_calendar_entry" >:: test_parse_calendar_entry;
   "test_parse_calendar_entry_with_extensions"
     >:: test_parse_calendar_entry_with_extensions;
   "test_calendar_entry_to_data_model" >:: test_calendar_entry_to_data_model;
   "test_parse_calendar_event_entry"
     >:: test_parse_calendar_event_entry]
