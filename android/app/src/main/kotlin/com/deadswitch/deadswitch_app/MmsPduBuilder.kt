package com.deadswitch.deadswitch_app

import java.io.ByteArrayOutputStream
import kotlin.random.Random

/**
 * Builds a binary MMS M-Send.req PDU for a text-only group message.
 * Encoding follows OMA MMS Encapsulation 1.2 / WAP WSP specifications.
 */
object MmsPduBuilder {

    // MMS header field codes (OMA-TS-MMS-ENC §7.3)
    private const val HDR_CONTENT_TYPE    = 0x84
    private const val HDR_DELIVERY_REPORT = 0x86
    private const val HDR_FROM            = 0x89
    private const val HDR_MESSAGE_TYPE    = 0x8C
    private const val HDR_MMS_VERSION     = 0x8D
    private const val HDR_TO              = 0x97
    private const val HDR_TRANSACTION_ID  = 0x98

    // Message type value: M-Send.req
    private const val MSG_TYPE_SEND_REQ   = 0x80

    // MMS version 1.2
    private const val MMS_VERSION_1_2     = 0x92

    // From: auto-insert device's own number
    private const val FROM_INSERT_ADDRESS = 0x81

    // No delivery report
    private const val BOOL_NO             = 0x81

    // Well-known content-type short integers (WAP WSP Table 40: value | 0x80)
    private const val CT_MULTIPART_MIXED  = 0xA3  // 0x23 | 0x80
    private const val CT_TEXT_PLAIN       = 0x83  // 0x03 | 0x80

    // WSP well-known parameter: charset (0x01 | 0x80)
    private const val PARAM_CHARSET       = 0x81

    // IANA charset 106 = UTF-8, encoded as short integer (106 | 0x80 = 0xEA)
    private const val CHARSET_UTF_8       = 0xEA

    /**
     * Returns binary PDU bytes for a group text MMS.
     * @param recipients  E.164 phone numbers, e.g. ["+12025551234", "+12025555678"]
     * @param body        Message text
     */
    fun buildGroupText(recipients: List<String>, body: String): ByteArray {
        val pdu = ByteArrayOutputStream()

        // X-Mms-Message-Type: M-Send.req
        pdu.writeByte(HDR_MESSAGE_TYPE)
        pdu.writeByte(MSG_TYPE_SEND_REQ)

        // X-Mms-Transaction-ID: random hex string
        pdu.writeByte(HDR_TRANSACTION_ID)
        pdu.writeNullString(Random.nextLong().toULong().toString(16).padStart(16, '0').takeLast(8))

        // X-Mms-MMS-Version: 1.2
        pdu.writeByte(HDR_MMS_VERSION)
        pdu.writeByte(MMS_VERSION_1_2)

        // To: one entry per recipient → creates a group thread
        for (phone in recipients) {
            pdu.writeByte(HDR_TO)
            pdu.writeNullString("${phone.trim()}/TYPE=PLMN")
        }

        // From: auto-insert the sender's SIM number
        pdu.writeByte(HDR_FROM)
        pdu.writeByte(0x01)                 // value-length = 1 byte
        pdu.writeByte(FROM_INSERT_ADDRESS)

        // X-Mms-Delivery-Report: No
        pdu.writeByte(HDR_DELIVERY_REPORT)
        pdu.writeByte(BOOL_NO)

        // Content-Type: application/vnd.wap.multipart.mixed
        pdu.writeByte(HDR_CONTENT_TYPE)
        pdu.writeByte(CT_MULTIPART_MIXED)

        // ── Multipart body ──────────────────────────────────────────
        // Number of parts
        pdu.writeUintvar(1L)

        // Part 1: text/plain; charset=UTF-8
        val textBytes   = body.toByteArray(Charsets.UTF_8)
        val partHeaders = buildTextPartHeaders()

        pdu.writeUintvar(partHeaders.size.toLong())  // header length
        pdu.writeUintvar(textBytes.size.toLong())    // data length
        pdu.write(partHeaders)
        pdu.write(textBytes)

        return pdu.toByteArray()
    }

    /** 3-byte header: Content-Type text/plain; charset=UTF-8 */
    private fun buildTextPartHeaders(): ByteArray {
        val h = ByteArrayOutputStream()
        h.writeByte(CT_TEXT_PLAIN)   // content type
        h.writeByte(PARAM_CHARSET)   // charset parameter
        h.writeByte(CHARSET_UTF_8)   // UTF-8
        return h.toByteArray()
    }

    // ── Encoding helpers ─────────────────────────────────────────────

    private fun ByteArrayOutputStream.writeByte(v: Int) = write(v and 0xFF)

    /** Null-terminated ISO-8859-1 text string. */
    private fun ByteArrayOutputStream.writeNullString(s: String) {
        write(s.toByteArray(Charsets.ISO_8859_1))
        write(0x00)
    }

    /** WAP WSP uintvar (variable-length unsigned integer). */
    private fun ByteArrayOutputStream.writeUintvar(value: Long) {
        if (value == 0L) { write(0x00); return }
        val bytes = mutableListOf<Int>()
        var v = value
        while (v > 0L) {
            bytes.add(0, (v and 0x7F).toInt())
            v = v ushr 7
        }
        for (i in bytes.indices) {
            write(if (i < bytes.size - 1) bytes[i] or 0x80 else bytes[i])
        }
    }
}
