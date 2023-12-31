// modules
include { PANORAMA_GET_RAW_FILE } from "../modules/panorama"
include { PANORAMA_GET_RAW_FILE_LIST } from "../modules/panorama"
include { MSCONVERT } from "../modules/msconvert"

workflow get_mzmls {

    emit:
       mzml_ch

    main:

        if(params.spectra_dir.contains("https://")) {

            spectra_dirs_ch = Channel.from(params.spectra_dir)
                                    .splitText()               // split multiline input
                                    .map{ it.trim() }          // removing surrounding whitespace
                                    .filter{ it.length() > 0 } // skip empty lines

            // get raw files from panorama
            PANORAMA_GET_RAW_FILE_LIST(spectra_dirs_ch, params.spectra_glob)

            placeholder_ch = PANORAMA_GET_RAW_FILE_LIST.out.raw_file_placeholders.transpose()
            PANORAMA_GET_RAW_FILE(placeholder_ch)
            
            mzml_ch = MSCONVERT(
                PANORAMA_GET_RAW_FILE.out.panorama_file
            )
            

        } else {

            file_glob = params.spectra_glob
            spectra_dir = file(params.spectra_dir, checkIfExists: true)
            data_files = file("$spectra_dir/${file_glob}")

            if(data_files.size() < 1) {
                error "No files found for: $spectra_dir/${file_glob}"
            }

            mzml_ch = null

            mzml_files = data_files.findAll { it.name.toLowerCase().endsWith('.mzml') }
            raw_files = data_files.findAll { it.name.toLowerCase().endsWith('.raw') }

            if(mzml_files.size() < 1 && raw_files.size() < 1) {
                error "No raw or mzML files found in: $spectra_dir"
            }

            if(mzml_files.size() > 0 && raw_files.size() > 0) {
                error "Matched raw files and mzML files for: $spectra_dir/${file_glob}. Please choose a file matching string that will only match one or the other."
            }

            if(mzml_files.size() > 0) {
                mzml_ch = Channel.fromList(mzml_files)
            } else {
                mzml_ch = MSCONVERT(
                        Channel.fromList(raw_files)
                )
            }

        }
}
