# Changelog

## [0.1.1](https://github.com/edlontech/zvex/compare/zvex-v0.1.0...zvex-v0.1.1) (2026-04-17)


### Features

* add add_column, drop_column, and alter_column DDL operations ([1cbd6bd](https://github.com/edlontech/zvex/commit/1cbd6bdf26cc6c5afc43a405dfc9771ab83152e3))
* add collection lifecycle NIF functions ([0c54149](https://github.com/edlontech/zvex/commit/0c541492853ae13080a111d0d9e426421eaa0a7a))
* add collection options introspection and schema introspection ([cf0c745](https://github.com/edlontech/zvex/commit/cf0c745b90f03aef825d2b43adcf133272382b89))
* add collection schema builder with validation ([ff1e34c](https://github.com/edlontech/zvex/commit/ff1e34cb511d6bc37f66fdbe6be1890ac6822c6c))
* add collection_query NIF and Zvex.execute delegation ([bb284bf](https://github.com/edlontech/zvex/commit/bb284bfa6c1234e2fbe29f8c5c8400052bf72886))
* add create_index and drop_index DDL operations ([7d3446e](https://github.com/edlontech/zvex/commit/7d3446ef7ead1c5aba94827647e1445d4c66216f))
* add Document CRUD API with integration tests ([c0d1f27](https://github.com/edlontech/zvex/commit/c0d1f27fc32d99e35290fa30c167f2df973a9c8e))
* add Document introspection, mutation, and Inspect protocol ([dca90f6](https://github.com/edlontech/zvex/commit/dca90f6cba3ae62a15717f67558633abec39ba62))
* add Document serialization, memory_usage, and detail_string NIFs ([3bb6ffa](https://github.com/edlontech/zvex/commit/3bb6ffa7b4859a52defe53aa73379a2d23f6a1ff))
* add initialize_with_config NIF for zvec config ([a6b610f](https://github.com/edlontech/zvex/commit/a6b610f33cf8ca7df253a7eb32465bdc67982f84))
* add NIF CRUD functions for document operations ([1cb6253](https://github.com/edlontech/zvex/commit/1cb6253c332775274ce67f3c92f36c77b3644826))
* add sparse vector NIF support for insert and fetch round-trip ([a2d1f86](https://github.com/edlontech/zvex/commit/a2d1f86d952e3c2eb7d827694542112e51ce28fa))
* add sparse vector support to Zvex.Vector ([67a72f7](https://github.com/edlontech/zvex/commit/67a72f7c6e0e35d47220f7dba3bd191057be32a9))
* add Splode error hierarchy with zvec error code mapping ([f216251](https://github.com/edlontech/zvex/commit/f216251c0fdcdd1fc5debeaa1e7cbbb35063e7e6))
* add top-level Zvex API with version, init, shutdown ([ce0a85b](https://github.com/edlontech/zvex/commit/ce0a85bb30aa5ff53f28eb6aa565d099a5992a49))
* add version check and type conversion utilities ([077eb2b](https://github.com/edlontech/zvex/commit/077eb2b8ccae2ec3d9af13870dea73c455389d7e))
* add Zigler NIF bindings for zvec version, init, shutdown ([de6efb0](https://github.com/edlontech/zvex/commit/de6efb0707eec6df44fd4f733886f0f4cb3a0145))
* add zvec submodule and elixir_make build pipeline ([db4d719](https://github.com/edlontech/zvex/commit/db4d7199fad062943adbfb5c651ae33a51c4760b))
* add Zvex.Config builder with Zoi validation ([b19b1a2](https://github.com/edlontech/zvex/commit/b19b1a2548d34cab2a352ec083ce72864ef1c8a8))
* add Zvex.Document struct with builder, validation, and NIF marshaling ([b0a384f](https://github.com/edlontech/zvex/commit/b0a384fdedbd974e5a5595e27e8b6c8f478302cc))
* add Zvex.Query builder and Zvex.Query.Result struct ([5a86cc3](https://github.com/edlontech/zvex/commit/5a86cc3c02f1180cef12d0eccf69fa60d79e9e35))
* add Zvex.Vector pure Elixir vector packing module ([583ddc5](https://github.com/edlontech/zvex/commit/583ddc5cad8a8e2a0ec0371aa53417b2729dd732))
* Implement Collection Lifecycle ([70d110a](https://github.com/edlontech/zvex/commit/70d110a386055dd7529778d0e0ebf0b31735562f))
* wire Zvex.initialize/1 to accept Config struct ([bb39218](https://github.com/edlontech/zvex/commit/bb3921803badff995ef7431fe3c0d3733db5ba8d))


### Bug Fixes

* add rpath handling and force rebuild for zvec ([3ee6652](https://github.com/edlontech/zvex/commit/3ee6652099c3af6367891617c205f87405fc7abc))
* atomic closed flag and null-check collection options ([2d4ec7b](https://github.com/edlontech/zvex/commit/2d4ec7bf22305d6b22d71edea116dc41f024503a))
* harden NIF layer against double-free, null derefs, and panics ([90b3e55](https://github.com/edlontech/zvex/commit/90b3e5553e81b6b6f76eeed940babb4ed11efea6))
* remove closed field and collection_close NIF to eliminate double-free race ([0cbe64c](https://github.com/edlontech/zvex/commit/0cbe64c6d7d767d3d5339e76c8999cb091cf495f))
* work around Query.flat() segfault by using HNSW linear scan ([3c7b816](https://github.com/edlontech/zvex/commit/3c7b8160e2ef5b00bc5e0c9aba6a4cd0135d7afc))


### Performance Improvements

* Added benchee for performance analysis ([b4dcaa1](https://github.com/edlontech/zvex/commit/b4dcaa10fb2cc1add7daa0fb922b3654efaff01c))
