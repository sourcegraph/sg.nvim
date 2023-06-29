extern crate proc_macro;
use {
    proc_macro::TokenStream,
    quote::quote,
    syn::{parse_macro_input, ItemStruct},
};

#[proc_macro_derive(LuaDefaults)]
pub fn userdata_defaults(input: TokenStream) -> TokenStream {
    let input = parse_macro_input!(input as ItemStruct);

    let name = input.ident;
    let generated = input
        .fields
        .iter()
        .map(|f| {
            let ident = f.ident.clone().expect("must have identifier for fields");
            let ident_str = format!("{ident}");
            quote! {
                fields.add_field_method_get(#ident_str, |lua, t| t.#ident.to_owned().to_lua(lua))
            }
        })
        .collect::<Vec<_>>();

    let expanded = quote! {
        impl #name {
            fn generate_default_fields<'lua, F: mlua::UserDataFields<'lua, Self>>(fields: &mut F) {
                #(#generated);*
            }
        }
    };

    TokenStream::from(expanded)
}
