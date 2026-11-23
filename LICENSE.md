# jsonW Sustainable Use License

Version 2.0 (2026-11-23). Replaces version 1.0 of 2026-11-06 (see section 15).
Owner: **WORTIC LTDA** (Wortic Tecnologia), CNPJ 37.853.407/0001-71, Brazil ("Wortic").

This is an English translation of [LICENCA.md](LICENCA.md). If they differ, the Portuguese text prevails.

jsonW is **not free software and not open source** as defined by the Open Source Initiative. It is proprietary software
owned by Wortic, **free of charge to use** within the limits below (a "fair-code" model). The source code of the core is
not public. jsonW is protected by Brazilian Law 9,609/1998 (computer programs) and Law 9,610/1998 (copyright), and is part
of the "Plataforma Wortic" program, filed for registration with INPI (Brazilian PTO), case BR 51 2026 011190-0.

## 1. Definitions
- **Software:** the specification, the tools (`wjsw`, `wjsw-cgi` and others), the libraries (including `libjsonw`, the
  Node.js module and the WebAssembly build), the ABI, the SDKs, the examples, the profiles, the documentation and the
  updates distributed by Wortic, through any channel (GitHub, npm, jsonw.org or other).
- **Core:** the internal columnar file layout, the codecs and compression, the wire protocol, custody, the permission view,
  encryption and the C code that implements them, published or not.
- **Your Data:** the files you write with the Software and their contents.
- **Competing Service:** a product or service, paid or free, whose main function is to store, convert, query, serve or
  transport data in the jsonW format for third parties, or that competes with jsonW as a format, library or database.

## 2. Acceptance
By downloading, installing, using, copying or distributing the Software you accept these terms. If you do not accept them,
do not use the Software. Whoever accepts on behalf of a company represents having authority to do so.

## 3. What you may do (free license)
Wortic grants you a **non-exclusive, non-transferable, non-sublicensable, royalty-free license, revocable upon breach**, to:
- use the Software on any number of **your own** computers, servers and applications, including your own commercial
  products and services, as long as jsonW is a **component** and not the service itself;
- copy and distribute the Software **unmodified**, as part of a product of yours, with these terms and the authorship
  notices (section 8);
- build programs, libraries and integrations that use the Software through the published APIs and SDKs, under any license
  you choose for **your own** code.

## 4. Your Data is yours
The files you write with the Software and their contents are yours. Wortic claims no right over them, and nothing in these
terms limits reading, storing or handing your files to whomever you want. Reading jsonW files with the Software itself,
with no time limit, is always allowed.

## 5. What you may not do
Without a written commercial agreement with Wortic, you may not:
1. Sell, rent, lease, sublicense, host or offer the Software, or a Competing Service, to third parties, paid or free,
   including as a managed service, cloud, API or platform-as-a-service.
2. Create, distribute or help create an independent, compatible, alternative or derivative implementation of the Core
   (a reader, writer, codec, converter or protocol that reads or writes the internal layout without using the Software).
3. Reverse engineer, decompile, disassemble, trace execution or otherwise attempt to extract the source code, algorithms,
   tables or parameters of the Core, except to the extent that applicable law expressly and non-waivably allows, and only
   to that exact extent.
4. Use the Software, its documentation, its test files, its outputs or its observed behavior to train, fine-tune, distill
   or evaluate artificial intelligence models for the purpose of reproducing the format, the Core or the Software, or of
   building a Competing Service.
5. Modify the Software and distribute the modified Software, or distribute parts of it apart from the original package.
6. Remove, alter or hide authorship, trademark, license or version notices, or circumvent any technical, license or
   custody control of the Software.
7. Use the Software to break the law or infringe third-party rights.

## 6. Commercial license
Hosting or offering jsonW as a service, distributing modified Software, embedding the Core in a product that competes with
it, or implementing the format independently requires a **commercial license** from Wortic, with price and conditions in a
separate contract. Contact: https://wortic.com.br.

## 7. Ownership, trade secrets and confidentiality
The Software, the Core and all copies are and remain Wortic's property; this license transfers no ownership. Everything
that is not in the public documentation (the internal layout, the codecs, the parameters and any information obtained
outside of it) is a **trade secret** of Wortic and may not be disclosed or used beyond what this document allows.

## 8. Required attribution
Every product that distributes the Software must include, in its documentation or credits screen, the notice:
"Uses jsonW, by Wortic (jsonw.org), under the jsonW Sustainable Use License."

## 9. Trademarks
"jsonW", "json Wondrous", "Wortic", "W-HLM" and the logos are trademarks of Wortic. You may truthfully state that your
product reads or writes jsonW. You may not use these marks in the name of your product, company or domain, nor suggest
partnership, certification or endorsement by Wortic, without written permission.

## 10. Patents
Wortic reserves all patent and invention rights over the Software and the Core. This license grants only the minimum
needed to use the Software as section 3 allows. If you (or a company in your group) file a claim alleging that the Software
infringes a patent or right of yours, this license terminates for you on the filing date.

## 11. Contributions
Contributions (code, documentation, reports, tests) are welcome and become part of the Software under these terms.
Contributors warrant they hold the rights to what they contribute and grant Wortic a perpetual, worldwide, irrevocable,
royalty-free license to use, modify, distribute, relicense and patent the contribution.

## 12. Compliance verification
With reasonable prior notice and at most once a year, Wortic may ask you to confirm in writing that your use complies with
these terms and what its scope is.

## 13. No warranty and limitation of liability
The Software is provided "as is", without warranty of any kind. To the maximum extent permitted by law, Wortic is not
liable for indirect damages, lost profits or data loss arising from the use of, or inability to use, the Software, and its
total liability is limited to what you paid for the Software (zero, under the free license).

## 14. Breach
Breaching these terms terminates the license automatically. For a first breach that you cure in good faith within 30 days
of notice, the license is reinstated; from the second breach on, it is not. Use outside these terms infringes copyright in
a computer program (Brazilian Law 9,609/1998) and subjects the infringer to injunction, seizure of copies and damages,
without prejudice to other legal remedies. Sections 5, 7, 9, 10 and 13 survive the end of the license.

## 15. Versions of these terms
Wortic may publish new versions of these terms. This version 2.0 applies to every copy of the Software obtained from
2026-11-23 on, of any version and through any channel. Copies obtained earlier remain governed by the terms that
accompanied them, for that copy.

## 16. General
If a clause is held invalid, the others remain in force, and the invalid one is replaced by the valid one closest to the
original intent. Not exercising a right is not a waiver of it. These terms are the entire agreement on the free license; a
written commercial agreement prevails over them on what it covers. If this translation and the Portuguese version differ,
the Portuguese version prevails.

## 17. Governing law and venue
Brazilian law. Venue: the courts of the district of Wortic's headquarters, waiving any other, however privileged.
