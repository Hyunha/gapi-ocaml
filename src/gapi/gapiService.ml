open GapiUtils.Infix

exception ServiceError of GapiError.RequestError.t

let parse_error pipe response_code =
  try
    let error = GapiJson.parse_json_response
                  GapiError.RequestError.of_data_model
                  pipe
    in
      raise (ServiceError error)
  with Json_type.Json_error _ ->
    GapiConversation.parse_error pipe response_code

let service_request
      ?post_data
      ?version
      ?etag
      ?query_parameters
      ?(request_type = GapiRequest.Query)
      url
      parse_response
      session =
  let query_url =
    Option.map_default
      (fun params -> GapiUtils.merge_query_string params url)
      url
      query_parameters
  in
    GapiRequest.gapi_request
      ?post_data
      ?version
      ?etag
      ~parse_error
      request_type
      query_url
      parse_response
      session

let service_request_with_data
      request_type
      data_to_post
      ?version
      ?etag
      ?query_parameters
      data
      url
      parse_response
      session =
  let post_data = data_to_post data in
    try
      service_request
        ~post_data
        ?version
        ?etag
        ?query_parameters
        ~request_type
        url
        parse_response
        session
    with GapiRequest.NotModified new_session ->
      (data, new_session)

let query
      ?version
      ?etag
      ?query_parameters
      url
      parse_response
      session =
  service_request
    ?version
    ?etag
    ?query_parameters
    ~request_type:GapiRequest.Query
    url
    parse_response
    session

let create
      data_to_post
      ?version
      ?query_parameters
      data
      url
      parse_response
      session =
  service_request_with_data
    GapiRequest.Create
    data_to_post
    ?version
    ?query_parameters
    data
    url
    parse_response
    session

let read
      ?version
      ?etag
      ?query_parameters
      data
      url
      parse_response
      session =
  try
    service_request
      ?version
      ?etag
      ?query_parameters
      url
      parse_response
      session
  with GapiRequest.NotModified new_session ->
    (data, new_session)

let update
      data_to_post
      ?version
      ?etag
      ?query_parameters
      data
      url
      parse_response
      session =
  service_request_with_data
    GapiRequest.Update
    data_to_post
    ?version
    ?etag
    ?query_parameters
    data
    url
    parse_response
    session

let patch
      data_to_post
      ?version
      ?etag
      ?query_parameters
      data
      url
      parse_response
      session =
  service_request_with_data
    GapiRequest.Patch
    data_to_post
    ?version
    ?etag
    ?query_parameters
    data
    url
    parse_response
    session

let delete
      ?version
      ?etag
      ?query_parameters
      url =
  service_request
    ?version
    ?etag
    ?query_parameters
    ~request_type:GapiRequest.Delete
    url
    GapiRequest.parse_empty_response

let batch_request
      data_to_post
      ?version
      data
      url
      parse_response
      session =
  service_request_with_data
    GapiRequest.Create
    data_to_post
    ?version
    data
    url
    parse_response
    session

module type QueryParameters = 
sig
  type t

  val default : t

  val to_key_value_list : t -> (string * string) list

end

let build_param default_params params get_value to_string name = 
  let value = get_value params in
    if value <> get_value default_params then
      [(name, to_string value)]
    else
      []

module StandardParameters =
struct
  type t = {
    fields : string;
    prettyPrint : bool;
    quotaUser : string;
    userIp : string
  }

  let default = {
    fields = "";
    prettyPrint = true;
    quotaUser = "";
    userIp = ""
  }

  let to_key_value_list qp =
    let param get_value to_string name =
      build_param default qp get_value to_string name
    in
      [param (fun p -> p.fields) Std.identity "fields";
       param (fun p -> p.prettyPrint) string_of_bool "prettyPrint";
       param (fun p -> p.quotaUser) Std.identity "quotaUser";
       param (fun p -> p.userIp) Std.identity "userIp"]
      |> List.concat

end

module type ServiceConf =
sig
  type resource_list_t
  type resource_t

  val service_url : string

  val parse_resource_list : GapiPipe.OcamlnetPipe.t -> resource_list_t

  val parse_resource : GapiPipe.OcamlnetPipe.t -> resource_t

  val render_resource : resource_t -> GapiCore.PostData.t

  val create_resource_from_id : string -> resource_t

  val get_url :
    ?container_id:string ->
    ?resource:resource_t ->
    string -> string

  val get_etag : resource_t -> string option

end

module type Service =
sig
  type resource_list_t
  type resource_t
  type query_parameters_t

  val list :
    ?url:string ->
    ?etag:string ->
    ?parameters:query_parameters_t ->
    ?container_id:string ->
    GapiConversation.Session.t ->
    (resource_list_t * GapiConversation.Session.t)

  val get :
    ?url:string ->
    ?parameters:query_parameters_t ->
    ?container_id:string ->
    string ->
    GapiConversation.Session.t ->
    (resource_t * GapiConversation.Session.t)

  val refresh :
    ?url:string ->
    ?parameters:query_parameters_t ->
    ?container_id:string ->
    resource_t ->
    GapiConversation.Session.t ->
    (resource_t * GapiConversation.Session.t)

  val insert :
    ?url:string ->
    ?parameters:query_parameters_t ->
    ?container_id:string ->
    resource_t ->
    GapiConversation.Session.t ->
    (resource_t * GapiConversation.Session.t)

  val update :
    ?url:string ->
    ?parameters:query_parameters_t ->
    ?container_id:string ->
    resource_t ->
    GapiConversation.Session.t ->
    (resource_t * GapiConversation.Session.t)

  val patch :
    ?url:string ->
    ?parameters:query_parameters_t ->
    ?container_id:string ->
    resource_t ->
    GapiConversation.Session.t ->
    (resource_t * GapiConversation.Session.t)

  val delete :
    ?url:string ->
    ?parameters:query_parameters_t ->
    ?container_id:string ->
    resource_t ->
    GapiConversation.Session.t ->
    (unit * GapiConversation.Session.t)

end

let map_standard_parameters =
  Option.map StandardParameters.to_key_value_list

module Make
  (S : ServiceConf)
  (Q : QueryParameters) =
struct
  type resource_list_t = S.resource_list_t
  type resource_t = S.resource_t
  type query_parameters_t = Q.t

  let map_parameters = Option.map Q.to_key_value_list

  let list
        ?(url = S.service_url)
        ?etag
        ?parameters
        ?container_id
        session =
    let url' = S.get_url ?container_id url in
    let query_parameters = map_parameters parameters in
      query
        ?etag
        ?query_parameters
        url'
        S.parse_resource_list
        session

  let get
        ?(url = S.service_url)
        ?parameters
        ?container_id
        id
        session =
    let resource = S.create_resource_from_id id in
    let url' = S.get_url ?container_id ~resource url in
    let query_parameters = map_parameters parameters in
      query
        ?query_parameters
        url'
        S.parse_resource
        session

  let refresh
        ?(url = S.service_url)
        ?parameters
        ?container_id
        resource
        session =
    let url' = S.get_url ?container_id ~resource url in
    let etag = S.get_etag resource in
    let query_parameters = map_parameters parameters in
      read
        ?etag
        ?query_parameters
        resource
        url'
        S.parse_resource
        session

  let insert
        ?(url = S.service_url)
        ?parameters
        ?container_id
        resource
        session =
    let url' = S.get_url ?container_id url in
    let query_parameters = map_parameters parameters in
      create
        ?query_parameters
        S.render_resource
        resource
        url'
        S.parse_resource
        session

  let update
        ?(url = S.service_url)
        ?parameters
        ?container_id
        resource
        session =
    let url' = S.get_url ?container_id ~resource url in
    let etag = S.get_etag resource in
    let query_parameters = map_parameters parameters in
      update
        S.render_resource
        ?etag
        ?query_parameters
        resource
        url'
        S.parse_resource
        session

  let patch
        ?(url = S.service_url)
        ?parameters
        ?container_id
        resource
        session =
    let url' = S.get_url ?container_id ~resource url in
    let etag = S.get_etag resource in
    let query_parameters = map_parameters parameters in
      patch
        S.render_resource
        ?etag
        ?query_parameters
        resource
        url'
        S.parse_resource
        session

  let delete
        ?(url = S.service_url)
        ?parameters
        ?container_id
        resource
        session =
    let url' = S.get_url ?container_id ~resource url in
    let etag = S.get_etag resource in
    let query_parameters = map_parameters parameters in
      delete
        ?etag
        ?query_parameters
        url'
        session

end

let get
      ?etag
      ?query_parameters
      url
      parse_response
      session =
  service_request
    ?etag
    ?query_parameters
    ~request_type:GapiRequest.Query
    url
    parse_response
    session

let post
      ?query_parameters
      ?(data_to_post = (fun _ -> GapiCore.PostData.empty))
      ~data
      url
      parse_response
      session =
  service_request_with_data
    GapiRequest.Create
    data_to_post
    ?query_parameters
    data
    url
    parse_response
    session

