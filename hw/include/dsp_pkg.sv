package dsp_pkg;

    parameter int ROM_ADDR_WIDTH   = 12;
    parameter int CLASSIFIER_ADDR_WIDTH   = 12;
    parameter int DATA_WIDTH   = 8;
    parameter int MAX_COLS     = 1280;
    parameter int MAX_ROWS = 720;
    parameter int SOBEL_THRESH = 100;
    parameter int AI_HAZARD_THRESH = 700;

    parameter string WEIGHT_FILE = "weights.hex"; // Path to the weights file

endpackage